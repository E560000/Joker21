-- game/round.lua  -  one blind: a sequence of blackjack hands scored Balatro-style
--
-- phase: idle -> player -> dealer -> scoring -> (idle | won | lost)

local Cards = require("game.cards")
local Score = require("game.score")
local State = require("game.state")

local Round = {}
Round.__index = Round

function Round.new(run, blind)
    local self = setmetatable({}, Round)
    self.run, self.blind, self.target = run, blind, blind.target
    self.score = 0
    self.handsLeft = run.hands
    for _, j in ipairs(run.jokers) do
        if j.def.extraHand then self.handsLeft = self.handsLeft + 1 end
    end
    self.deck = Cards.shuffle(Cards.newDeck())
    self.discard = {}
    self.player, self.dealer = {}, {}
    self.phase = "idle"
    self.holeRevealed = false
    self.doubled = false
    self.steps, self.finalScore, self.cost = {}, 0, 1
    self.insured = false
    self.lossBonus = 0
    for _, j in ipairs(run.jokers) do
        j.state.used, j.state.deckPeekUsed = false, false
    end
    return self
end

function Round:saveState()
    return { ante = self.blind.ante, blindIdx = self.blind.idx,
        score = self.score, handsLeft = self.handsLeft, deck = self.deck,
        discard = self.discard, player = self.player, dealer = self.dealer,
        phase = self.phase, holeRevealed = self.holeRevealed, doubled = self.doubled,
        insured = self.insured, result = self.result, cost = self.cost,
        finalScore = self.finalScore, potentialScore = self.potentialScore,
        lossBonus = self.lossBonus }
end

function Round.restore(run, blind, state)
    if type(state) ~= "table" then return nil end
    if (state.ante ~= nil and state.ante ~= blind.ante)
        or (state.blindIdx ~= nil and state.blindIdx ~= blind.idx) then return nil end
    local phases = { idle = true, player = true, dealer = true, scoring = true, won = true, lost = true }
    local results = { win = true, lose = true, bust = true, push = true }
    if not phases[state.phase] or not State.integer(state.score, 0)
        or not State.integer(state.handsLeft, 0) then return nil end
    if state.phase == "scoring" and not results[state.result] then return nil end
    for _, key in ipairs({ "finalScore", "potentialScore", "lossBonus" }) do
        if state[key] ~= nil and not State.integer(state[key], 0) then return nil end
    end
    if state.cost ~= nil and not State.integer(state.cost, 0, 2) then return nil end
    local seen, count = {}, 0
    local function validCard(card)
        if type(card) ~= "table" then return false end
        local rank, suit = false, false
        for _, r in ipairs(Cards.RANKS) do if card.rank == r then rank = true end end
        for _, s in ipairs(Cards.SUITS) do if card.suit == s then suit = true end end
        if not rank or not suit then return false end
        local name = Cards.name(card)
        if seen[name] then return false end
        seen[name], count = true, count + 1
        return true
    end
    for _, key in ipairs({ "deck", "discard", "player", "dealer" }) do
        if not State.array(state[key], validCard, 52) then return nil end
    end
    if count ~= 52 then return nil end
    local active = state.phase == "player" or state.phase == "dealer" or state.phase == "scoring"
    if active and (#state.player < 2 or #state.dealer < 2) then return nil end
    if not active and (#state.player > 0 or #state.dealer > 0) then return nil end
    local self = setmetatable({}, Round)
    self.run, self.blind, self.target = run, blind, blind.target
    for _, key in ipairs({ "score", "handsLeft", "deck", "discard", "player", "dealer", "phase", "result" }) do
        self[key] = state[key]
    end
    self.holeRevealed, self.doubled, self.insured = state.holeRevealed == true,
        state.doubled == true, state.insured == true
    self.cost = state.cost or (self.doubled and 2 or 1)
    self.steps, self.finalScore = {}, state.finalScore or 0
    self.potentialScore, self.lossBonus = state.potentialScore or 0, state.lossBonus or 0
    if self.phase == "idle" or self.phase == "lost" then
        if self.score >= self.target then self.phase = "won"
        elseif self.handsLeft <= 0 then self.phase = "lost"
        elseif self.phase == "lost" then return nil end
    elseif self.phase == "won" and self.score < self.target then
        return nil
    end
    if self.phase == "scoring" then
        local scoring = Score.compute(self)
        self.potentialScore = scoring.score
        if self.result == "win" then self.steps, self.finalScore = scoring.steps, scoring.score end
        self.lossBonus = self:lossScore()
    end
    return self
end

function Round:peekActive()
    for _, j in ipairs(self.run.jokers) do
        if j.def.peek then return true end
    end
    return false
end

function Round:bossActive()
    if not self.blind.boss then return false end
    for _, j in ipairs(self.run.jokers) do
        if j.def.bossImmunity then return false end
    end
    return true
end

function Round:deckPeekActive()
    for _, j in ipairs(self.run.jokers) do
        if j.def.deckPeek and not j.state.deckPeekUsed then return true end
    end
    return false
end

function Round:useDeckPeek()
    if not self:deckPeekActive() then return nil end
    for _, j in ipairs(self.run.jokers) do
        if j.def.deckPeek and not j.state.deckPeekUsed then
            j.state.deckPeekUsed = true
            return self.deck[#self.deck]
        end
    end
end

function Round:standAt()
    local boss = self:bossActive() and self.blind.boss
    return (boss and boss.standAt) or 17
end

function Round:draw()
    if #self.deck == 0 then
        self.deck, self.discard = self.discard, {}
        Cards.shuffle(self.deck)
    end
    return table.remove(self.deck)
end

function Round:deal()
    if self.phase ~= "idle" or self.handsLeft <= 0 then return false end
    if #self.deck < 14 then
        for _, c in ipairs(self.discard) do self.deck[#self.deck + 1] = c end
        self.discard = {}
        Cards.shuffle(self.deck)
    end
    self.player, self.dealer = {}, {}
    self.player[1] = self:draw()
    self.dealer[1] = self:draw()
    self.player[2] = self:draw()
    self.dealer[2] = self:draw()
    self.holeRevealed, self.doubled, self.insured, self.result = false, false, false, nil
    self.lossBonus = 0
    self.phase = "player"
    -- A dealer natural beats every non-natural player hand. Resolve it
    -- immediately so the player is never offered actions that cannot win.
    if Cards.isNatural(self.dealer) and not Cards.isNatural(self.player) then
        self:resolve()
    elseif Cards.isNatural(self.player) then
        self:stand()
    end
    return true
end

function Round:hit()
    if self.phase ~= "player" then return false end
    self.player[#self.player + 1] = self:draw()
    local t = Score.handTotal(self)
    if t > 21 then self:resolve()
    elseif t == 21 then self:stand() end
    return true
end

function Round:stand()
    if self.phase ~= "player" then return false end
    self.phase = "dealer"
    self.holeRevealed = true
    return true
end

function Round:canDouble()
    return self.phase == "player" and #self.player == 2 and self.handsLeft >= 2
end

function Round:double()
    if not self:canDouble() then return false end
    self.doubled = true
    self.player[#self.player + 1] = self:draw()
    if Score.handTotal(self) > 21 then self:resolve() else self:stand() end
    return true
end

-- Draws one dealer card if needed. Returns true if a card was drawn; when the
-- dealer is finished it resolves the hand and returns false.
function Round:dealerStep()
    if self.phase ~= "dealer" then return false end
    if Cards.total(self.dealer) < self:standAt() then
        self.dealer[#self.dealer + 1] = self:draw()
        return true
    end
    self:resolve()
    return false
end

function Round:resolve()
    local pt, dt = Score.handTotal(self), Cards.total(self.dealer)
    local pn, dn = Cards.isNatural(self.player), Cards.isNatural(self.dealer)
    local boss = self:bossActive() and self.blind.boss
    self.holeRevealed = true
    local res
    if pt > 21 then res = "bust"
    elseif dt > 21 then res = "win"
    elseif pn and not dn then res = "win"
    elseif dn and not pn and pt ~= 21 then res = "lose"
    elseif pt > dt then res = "win"
    elseif pt < dt then res = "lose"
    else res = "push" end
    if res == "push" and boss and boss.pushLoses then res = "lose" end

    self.result = res
    self.cost = self.doubled and 2 or 1
    if res == "push" then
        self.cost = 0
    elseif res == "bust" then
        for _, j in ipairs(self.run.jokers) do
            if j.def.insurance and not j.state.used then
                j.state.used = true
                self.insured, self.cost = true, 0
                break
            end
        end
    end

    self.steps, self.finalScore = {}, 0
    local scoring = Score.compute(self)
    self.potentialScore = scoring.score
    if res == "win" then self.steps, self.finalScore = scoring.steps, scoring.score end
    self.lossBonus = self:lossScore()
    self.phase = "scoring"
end

function Round:lossScore()
    local bonus = 0
    if self.result == "lose" then
        local ctx = { result = self.result, doubled = self.doubled,
            potentialScore = self.potentialScore or 0 }
        for _, j in ipairs(self.run.jokers) do
            if j.def.onLoss then bonus = bonus + j.def.onLoss(ctx, j) end
        end
    end
    return bonus
end

function Round:finishHand()
    if self.phase ~= "scoring" then return false end
    local run = self.run
    local ctx = { result = self.result, doubled = self.doubled,
        potentialScore = self.potentialScore or 0 }
    if self.result == "win" then
        self.score = self.score + self.finalScore
        run.stats.wins = run.stats.wins + 1
        run.stats.best = math.max(run.stats.best, self.finalScore)
    end
    if self.result == "lose" then
        self.score = self.score + (self.lossBonus or 0)
    end
    run.stats.hands = run.stats.hands + 1
    for _, j in ipairs(run.jokers) do
        if j.def.onHandEnd then j.def.onHandEnd(ctx, j) end
    end
    for _, c in ipairs(self.player) do self.discard[#self.discard + 1] = c end
    for _, c in ipairs(self.dealer) do self.discard[#self.discard + 1] = c end
    self.player, self.dealer = {}, {}
    self.handsLeft = self.handsLeft - self.cost
    if self.score >= self.target then self.phase = "won"
    elseif self.handsLeft <= 0 then self.phase = "lost"
    else self.phase = "idle" end
    return true
end

return Round
