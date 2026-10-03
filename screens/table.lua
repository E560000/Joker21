local T = require("ui.theme")
local W = require("ui.widgets")
local E = require("lib.easing")
local C = require("ui.cardart")
local Sprite = require("ui.sprite")
local Cards = require("game.cards")
local Round = require("game.round")
local Score = require("game.score")
local Run = require("game.run")
local App = require("app")
local Audio = require("game.audio")

local Table = {}

local PCX = 740
local DEALER_Y, PLAYER_Y = 268, 470
local DECK_X, DECK_Y = 1160, 420
local JOKER_X0, JOKER_SP, JOKER_Y = 360, 100, 84
local TYPE_COL = { { 0.45, 0.70, 1.00 }, { 1.00, 0.72, 0.25 }, { 1.00, 0.35, 0.38 } }

local function speedF() return ({ 1, 0.5, 0.06 })[T.opts.speed] or 1 end

local function fmtNum(n)
    if n == math.floor(n) then return T.commas(n) end
    local s = string.format("%.2f", n)
    s = s:gsub("0+$", "")
    s = s:gsub("%.$", "")
    return s
end

-- ---------------------------------------------------------------- setup

function Table:enter()
    local run = Run.cur
    self.run = run
    self.blind = run:currentBlind()
    local savedRound = run.savedRound
    -- A blind ends in `won` or `lost`; neither phase can deal another hand.
    -- Older release builds could carry the previous blind's won round into
    -- the next blind, so discard terminal snapshots when resuming a run.
    if savedRound and (savedRound.phase == "won" or savedRound.phase == "lost") then
        savedRound = nil
        run.savedRound = nil
    end
    self.round = (savedRound and Round.restore(run, self.blind, savedRound)) or Round.new(run, self.blind)
    local savedPhase = self.round.phase
    self:saveProgress()
    self.sprites, self.order, self.jsprites, self.popups = {}, {}, {}, {}
    self.mode, self.timer, self.seq, self.t = "idle", 0, 0, 0
    self.shownScore = 0
    self.dispChips, self.dispMult = 0, 0
    self.chipsBump, self.multBump = 0, 0
    self.banner, self.paused = nil, false
    self.deckPeekCard, self.deckPeekTimer = nil, 0
    self.draggingJoker = nil
    self.scoreCallout, self.chainCount = nil, 0
    self.stepIdx, self.stepT, self.tallied = 0, 0, false
    if savedPhase == "player" then self.mode = "player"
    elseif savedPhase == "dealer" then self.mode, self.timer = "dealer", 0.1
    elseif savedPhase == "scoring" then self.mode = "scoring"; self.stepT = 0.1 end
    for i, j in ipairs(run.jokers) do
        local x = JOKER_X0 + (i - 1) * JOKER_SP
        local s = Sprite.new(x, JOKER_Y - 90)
        s.tx, s.ty, s.wait = x, JOKER_Y, 0.05 * i
        self.jsprites[j] = s
    end
    self:layout()
    self:buildGroups()
    if savedPhase == "scoring" then self:beginScoring() end
    self:updateButtons()
end

function Table:saveProgress()
    self.run.savedRound = self.round:saveState()
    self.run:save(self.run.savedRound)
end

function Table:buildGroups()
    local act = W.group()
    self.act = act
    self.bDeal = act:add(W.button { x = 620, y = 628, w = 240, h = 64, label = "Deal", icon = "play",
        primary = true, hint = "Space", onClick = function() self:doDeal() end })
    self.bHit = act:add(W.button { x = 432, y = 628, w = 196, h = 64, label = "Hit", icon = "plus",
        hint = "H", onClick = function() self:doHit() end })
    self.bStand = act:add(W.button { x = 642, y = 628, w = 196, h = 64, label = "Stand", icon = "pause",
        hint = "S", onClick = function() self:doStand() end })
    self.bDouble = act:add(W.button { x = 852, y = 628, w = 196, h = 64, label = "Double", size = 20,
        sub = "x2 score, 2 hands", icon = "next", hint = "D", onClick = function() self:doDouble() end })

    local pg = W.group()
    self.pauseG = pg
    pg:add(W.button { x = 504, y = 270, w = 272, h = 54, label = "Resume", icon = "play", primary = true,
        onClick = function() self:setPaused(false) end })
    pg:add(W.button { x = 504, y = 334, w = 272, h = 54, label = "Quit to Menu", icon = "quit", danger = true,
        onClick = function() App.go("menu") end })

    local cg = W.group()
    self.cashG = cg
    cg:add(W.button { x = 520, y = 510, w = 240, h = 56, label = "Cash Out", icon = "next", primary = true,
        onClick = function() self:finishCash() end })
end

function Table:setPaused(v)
    self.paused = v
    if v then
        self.pauseG.focus = 1
        self.pauseG:playIntro(0.05)
    end
end

function Table:updateButtons()
    local m = self.mode
    self.bDeal.hidden = (m ~= "idle")
    local show = (m ~= "idle") and (m ~= "cashout") and (m ~= "leaving")
    for _, b in ipairs({ self.bHit, self.bStand, self.bDouble }) do
        b.hidden = not show
        b.enabled = (m == "player")
    end
    self.bDouble.enabled = (m == "player") and self.round:canDouble()
    self.act.focus = (m == "idle") and 1 or ((m == "player") and 2 or 0)
end

-- ---------------------------------------------------------------- actions

function Table:doDeal()
    if self.mode ~= "idle" then return end
    self.seq, self.banner = 0, nil
    self.dispChips, self.dispMult = 0, 0
    if not self.round:deal() then return end
    self:saveProgress()
    self:layout()
    self.mode, self.timer = "dealing", 1.05 * math.max(speedF(), 0.35)
    self:updateButtons()
end

local function afterAction(self)
    local p = self.round.phase
    self:layout()
    if p == "player" then
        self.mode = "player"
    elseif p == "dealer" then
        self.mode, self.timer = "dealer", 0.7 * math.max(speedF(), 0.15)
    elseif p == "scoring" then
        self:beginScoring()
    end
    self:updateButtons()
end

function Table:doHit()
    if self.mode ~= "player" then return end
    self.seq = 0
    self.round:hit()
    self:saveProgress()
    self:layout()
    self.mode, self.timer = "dealing", 0.5 * math.max(speedF(), 0.3)
    self:updateButtons()
end

function Table:doStand()
    if self.mode ~= "player" then return end
    self.round:stand()
    self:saveProgress()
    self:layout()
    self.mode, self.timer = "dealing", 0.4 * math.max(speedF(), 0.3)
    self:updateButtons()
end

function Table:doDouble()
    if self.mode ~= "player" or not self.round:canDouble() then return end
    self.seq = 0
    self.round:double()
    self:saveProgress()
    self:layout()
    self.mode, self.timer = "dealing", 0.6 * math.max(speedF(), 0.3)
    self:updateButtons()
end

function Table:layout()
    local r = self.round
    local function ensure(card)
        if not self.sprites[card] then
            local s = Sprite.new(DECK_X, DECK_Y)
            s.sc, s.tsc, s.flip, s.tflip, s.rot = 0.65, 1, 0, 0, 0.5
            s.wait = self.seq * 0.17
            s.drawSoundPending = true
            self.seq = self.seq + 1
            self.sprites[card] = s
            self.order[#self.order + 1] = card
        end
    end
    for i = 1, math.max(#r.player, #r.dealer) do
        if r.player[i] then ensure(r.player[i]) end
        if r.dealer[i] then ensure(r.dealer[i]) end
    end
    local function place(hand, y, isDealer)
        local n = #hand
        local sp = math.min(84, 480 / math.max(n, 1))
        for i, card in ipairs(hand) do
            local s = self.sprites[card]
            local off = (i - 1) - (n - 1) / 2
            s.tx, s.ty, s.trot, s.tsc = PCX + off * sp, y, off * 0.03, 1
            local up = true
            s.peek = false
            if isDealer and i == 2 and not r.holeRevealed then
                if r:peekActive() then s.peek = true else up = false end
            end
            s.tflip = up and 1 or 0
        end
    end
    place(r.player, PLAYER_Y, false)
    place(r.dealer, DEALER_Y, true)
end

-- ---------------------------------------------------------------- scoring

function Table:popup(x, y, text, color, life, size)
    self.popups[#self.popups + 1] = { x = x, y = y, text = text, color = color,
        age = 0, life = life or 1.0, size = size or 26 }
end

function Table:beginScoring()
    local r = self.round
    self.mode, self.stepIdx, self.tallied = "scoring", 0, false
    self.scoreCallout, self.chainCount = nil, 0
    self.stepT = 0.55 * speedF() + 0.05
    local texts = { win = "WIN", lose = "DEALER WINS", bust = "BUST", push = "PUSH" }
    local cols = { win = T.c.gold, lose = T.c.bad, bust = T.c.bad, push = T.c.dim }
    local txt = texts[r.result]
    if r.result == "win" and Cards.isNatural(r.player) then txt = "BLACKJACK!" end
    if r.result == "win" then Audio.play("win")
    elseif r.result == "lose" or r.result == "bust" then Audio.play("loss") end
    self.banner = { text = txt, color = cols[r.result], t = 0 }
    if r.result == "lose" and r.lossBonus and r.lossBonus > 0 then
        self.banner.sub = "Pity: +" .. T.commas(r.lossBonus) .. " chips"
    end
    if r.insured then self.banner.sub = "Insured - hand refunded"
    elseif r.result == "push" then self.banner.sub = "Hand refunded" end
    if r.result == "win" then
        self.dispChips, self.dispMult = Score.BASE_CHIPS, Score.BASE_MULT
        self.chipsBump, self.multBump = 1, 1
    end
end

function Table:applyStep(st)
    local r = self.round
    self.dispChips, self.dispMult = st.cAfter, st.mAfter
    local changes = {}
    if st.chips then changes[#changes + 1] = "+" .. fmtNum(st.chips) .. " chips" end
    if st.mult then changes[#changes + 1] = "+" .. fmtNum(st.mult) .. " Mult" end
    if st.xmult then changes[#changes + 1] = "X" .. fmtNum(st.xmult) .. " Mult" end
    if #changes > 0 then
        self.chainCount = self.chainCount + 1
        self.scoreCallout = table.concat(changes, "    ")
        Audio.play("points", math.min(1.7, 1 + (self.chainCount - 1) * 0.08))
    end
    local src
    if st.kind == "card" then
        src = self.sprites[r.player[st.cardIndex]]
    elseif st.kind == "joker" then
        src = self.jsprites[st.joker]
        if st.cardIndex then
            local cs = self.sprites[r.player[st.cardIndex]]
            if cs then cs.bump = 1 end
        end
    end
    if src then
        src.bump = 1
    end
    if st.label then self:popup(PCX, 340, st.label, T.c.gold, 1.2, 24) end
    if st.chips then
        self.chipsBump = 1
    end
    if st.mult then
        self.multBump = 1
    end
    if st.xmult then
        self.multBump = 1
    end
end

function Table:updateScoring(dt)
    self.stepT = self.stepT - dt
    if self.stepT > 0 then return end
    local r, f = self.round, speedF()
    if self.stepIdx < #r.steps then
        self.stepIdx = self.stepIdx + 1
        local st = r.steps[self.stepIdx]
        self:applyStep(st)
        self.stepT = ((st.kind == "card") and 0.40 or 0.62) * f
    elseif not self.tallied then
        self.tallied = true
        if r.result == "win" then
            self.scoreCallout = "HAND SCORE  +" .. T.commas(r.finalScore)
        end
        self.stepT = 0.95 * f + 0.1
    else
        if self.round.result == "win" then Audio.play("score_end") end
        self:endHand()
    end
end

function Table:endHand()
    self.round:finishHand()
    self:saveProgress()
    self.mode, self.timer, self.banner = "sweep", 0.5 * math.max(speedF(), 0.3), nil
    for _, s in pairs(self.sprites) do
        s.tx, s.tsc, s.trot = DECK_X + 260, 0.6, 0.6
    end
    self:updateButtons()
end

function Table:afterSweep()
    self.sprites, self.order = {}, {}
    local p = self.round.phase
    if p == "won" then
        self.mode, self.cashT = "cashout", 0
        self.cashLines, self.cashTotal = self.run:cashOut(self.round)
        self.cashG.focus = 1
        self.cashG:playIntro(0.05)
    elseif p == "lost" then
        self.mode = "leaving"
        App.go("gameover", "fade", { victory = false })
    else
        self.mode = "idle"
    end
    self:updateButtons()
end

function Table:finishCash()
    if self.mode ~= "cashout" then return end
    self.mode = "leaving"
    self.run:advance()
    if self.run.victory then
        App.go("gameover", "fade", { victory = true })
    else
        self.run:genShop()
        App.go("shop", "iris")
    end
end

-- ---------------------------------------------------------------- update

function Table:update(dt)
    self.t = self.t + dt
    if self.deckPeekTimer > 0 then
        self.deckPeekTimer = math.max(0, self.deckPeekTimer - dt)
        if self.deckPeekTimer == 0 then self.deckPeekCard = nil end
    end
    if self.paused then
        self.pauseG:update(dt, App.mx, App.my)
        return
    end
    self.act:update(dt, App.mx, App.my)
    if self.mode == "cashout" then
        self.cashT = self.cashT + dt
        self.cashG:update(dt, App.mx, App.my)
    end

    for _, s in pairs(self.sprites) do
        Sprite.update(s, dt)
        if s.drawSoundPending and s.wait <= 0 then
            s.drawSoundPending = nil
            Audio.play("card_draw")
        end
    end
    self.hoverJoker = nil
    for _, j in ipairs(self.run.jokers) do
        local s = self.jsprites[j]
        if self.draggingJoker == j then
            s.x, s.y = App.mx, App.my
            s.tx, s.ty = App.mx, App.my
        end
        Sprite.update(s, dt)
        local hov = Sprite.hit(s, App.mx, App.my, C.JW, C.JH)
        s.thover = hov and 1 or 0
        if hov then self.hoverJoker = j end
    end

    self.chipsBump = math.max(0, self.chipsBump - dt * 3.5)
    self.multBump = math.max(0, self.multBump - dt * 3.5)
    local target = self.round.score
    if T.opts.speed == 3 or T.opts.reducedMotion then
        self.shownScore = target
    else
        self.shownScore = self.shownScore + (target - self.shownScore) * math.min(1, dt * 6)
        if math.abs(target - self.shownScore) < 1 then self.shownScore = target end
    end
    for i = #self.popups, 1, -1 do
        local p = self.popups[i]
        p.age = p.age + dt
        if p.age > p.life then table.remove(self.popups, i) end
    end
    if self.banner then self.banner.t = self.banner.t + dt end

    local m = self.mode
    if m == "dealing" then
        self.timer = self.timer - dt
        if self.timer <= 0 then afterAction(self) end
    elseif m == "dealer" then
        self.timer = self.timer - dt
        if self.timer <= 0 then
            self.seq = 0
            local drew = self.round:dealerStep()
            self:layout()
            if drew then
                self.timer = 0.7 * math.max(speedF(), 0.15)
            else
                afterAction(self)
            end
        end
    elseif m == "scoring" then
        self:updateScoring(dt)
    elseif m == "sweep" then
        self.timer = self.timer - dt
        if self.timer <= 0 then self:afterSweep() end
    end
end

-- ---------------------------------------------------------------- drawing

local function statBox(x, y, w, h, str, col, bump)
    local g = love.graphics
    g.push()
    g.translate(x + w / 2, y + h / 2)
    local s = 1 + 0.14 * bump
    g.scale(s, s)
    T.set(col, 0.20)
    T.rrect("fill", -w / 2, -h / 2, w, h, 10)
    g.setLineWidth(2)
    T.set(col)
    T.rrect("line", -w / 2, -h / 2, w, h, 10)
    local size = (#str <= 4) and 36 or ((#str <= 6) and 28 or 21)
    T.textBox(str, -w / 2, -h / 2, w, h, size, T.c.text, "center", "display")
    g.pop()
end

function Table:drawSidebar()
    local g = love.graphics
    local b, r, run = self.blind, self.round, self.run
    local col = TYPE_COL[b.idx]

    W.panel(16, 16, 276, 172)
    T.set(col, 0.9)
    g.rectangle("fill", 32, 28, 244, 4, 2, 2)
    T.text(b.name, 32, 38, T.fs(24), col, "left", 244, "display")
    T.text("Score at least", 32, 72, T.fs(12), T.c.dim)
    T.text(T.commas(b.target), 32, 86, T.fs(34), T.c.text, "left", nil, "display")
    T.text("Reward  " .. string.rep("$", b.reward), 32, 128, T.fs(16), T.c.gold)
    if b.boss then
        T.text(b.boss.desc, 32, 152, T.fs(12), T.c.bad, "left", 244)
    end

    W.panel(16, 198, 276, 88)
    T.spaced("ROUND SCORE", 32, 208, T.fs(11), T.c.dim, 3)
    T.text(T.commas(math.floor(self.shownScore + 0.5)), 32, 222, T.fs(34), T.c.text, "left", nil, "display")
    T.set(T.c.dark)
    g.rectangle("fill", 32, 266, 244, 8, 4, 4)
    T.set(col)
    g.rectangle("fill", 32, 266, math.max(0, 244 * T.clamp(self.shownScore / b.target, 0, 1)), 8, 4, 4)

    W.panel(16, 296, 276, 120)
    T.spaced("CHIPS", 36, 306, T.fs(11), T.c.chips, 3)
    T.spaced("MULT", 188, 306, T.fs(11), T.c.mult, 3)
    statBox(28, 328, 106, 76, fmtNum(self.dispChips), T.c.chips, self.chipsBump)
    T.textBox("x", 132, 328, 32, 76, 30, T.c.text, "center", "display")
    statBox(162, 328, 106, 76, fmtNum(self.dispMult), T.c.mult, self.multBump)

    W.panel(16, 426, 276, 96)
    T.spaced("HANDS", 36, 438, T.fs(11), T.c.dim, 3)
    T.text(tostring(r.handsLeft), 36, 456, T.fs(44), T.c.chips, "left", nil, "display")
    T.spaced("MONEY", 166, 438, T.fs(11), T.c.dim, 3)
    T.text("$" .. run.money, 166, 456, T.fs(44), T.c.gold, "left", nil, "display")

    W.panel(16, 532, 276, 80)
    T.spaced("ANTE", 36, 544, T.fs(11), T.c.dim, 3)
    T.text(run.ante .. " / " .. #require("game.blinds").BASE, 36, 562, T.fs(26), T.c.text, "left", nil, "display")
    T.spaced("DECK", 166, 544, T.fs(11), T.c.dim, 3)
    T.text(tostring(#r.deck), 166, 562, T.fs(26), T.c.text, "left", nil, "display")

    local fx = 32
    fx = fx + T.keycap("Esc", fx, 630, 24) + 6
    T.text("Pause", fx, 633, T.fs(13), T.c.dim)
end

local function dealerStr(self)
    local r = self.round
    local d = r.dealer
    if #d == 0 then return "-" end
    if r.holeRevealed or (r:peekActive() and #d >= 2) then
        return tostring((Cards.total(d)))
    end
    return tostring(Cards.chips(d[1])) .. " + ?"
end

function Table:drawHandLabels()
    local r = self.round
    T.spaced("DEALER", 320, DEALER_Y - 56, T.fs(12), T.c.dim, 3)
    T.text(dealerStr(self), 320, DEALER_Y - 38, T.fs(30), T.c.text, "left", nil, "display")
    local st = self.blind.boss and self.blind.boss.standAt or 17
    T.text("stands on " .. st, 320, DEALER_Y - 2, T.fs(12), T.c.dim)

    T.spaced("YOU", 320, PLAYER_Y - 56, T.fs(12), T.c.dim, 3)
    if #r.player > 0 then
        local t, soft = Score.handTotal(r)
        local col = (t > 21) and T.c.bad or ((t == 21) and T.c.gold or T.c.text)
        T.text(tostring(t), 320, PLAYER_Y - 38, T.fs(30), col, "left", nil, "display")
        if soft and t <= 21 then T.text("soft", 320, PLAYER_Y - 2, T.fs(12), T.c.dim) end
        if t > 21 then T.text("bust", 320, PLAYER_Y - 2, T.fs(12), T.c.bad) end
    else
        T.text("-", 320, PLAYER_Y - 38, T.fs(30), T.c.dim, "left", nil, "display")
    end
end

function Table:drawCards()
    for _, card in ipairs(self.order) do
        local s = self.sprites[card]
        if s then
            Sprite.draw(s, function()
                C.face(card, C.CW, C.CH)
                if s.peek then
                    T.set({ 0, 0, 0 }, 0.38)
                    T.rrect("fill", -C.CW / 2, -C.CH / 2, C.CW, C.CH, 10)
                    T.textBox("PEEK", -C.CW / 2, C.CH / 2 - 30, C.CW, 24, 13, T.c.gold, "center")
                end
            end, function() C.back(C.CW, C.CH) end)
        end
    end
end

function Table:draw()
    local g = love.graphics
    local r, run = self.round, self.run

    self:drawSidebar()

    -- jokers
    for i = 1, run.slots do
        g.push()
        g.translate(JOKER_X0 + (i - 1) * JOKER_SP, JOKER_Y)
        C.jokerSlot()
        g.pop()
    end
    for _, j in ipairs(run.jokers) do
        local s = self.jsprites[j]
        Sprite.draw(s, function() C.joker(j.def) end, function() C.back() end)
    end
    T.spaced("JOKERS " .. #run.jokers .. "/" .. run.slots, 1010, 60, T.fs(11), T.c.dim, 3)

    -- felt table line
    g.setLineWidth(2)
    T.set(T.c.line, 0.35)
    g.line(330, 372, 1150, 372)

    self:drawHandLabels()

    -- deck pile
    for i = 3, 1, -1 do
        g.push()
        g.translate(DECK_X - i * 2, DECK_Y - i * 2)
        C.back(C.CW * 0.9, C.CH * 0.9)
        g.pop()
    end
    T.text(#r.deck .. " left", DECK_X - 50, DECK_Y + 84, T.fs(13), T.c.dim, "center", 100)

    if self.deckPeekCard then
        W.panel(DECK_X - 108, DECK_Y - 132, 216, 112)
        T.text("TOP CARD", DECK_X - 92, DECK_Y - 118, T.fs(11), T.c.gold, "left", 184)
        T.text(Cards.name(self.deckPeekCard), DECK_X - 92, DECK_Y - 88, T.fs(26), T.c.text, "center", 184, "display")
    end

    self:drawCards()

    if self.mode == "scoring" and self.scoreCallout then
        W.panel(420, 554, 640, 60)
        T.textBox("SCORING", 432, 554, 112, 60, T.fs(13), T.c.dim, "center")
        T.textBox(self.scoreCallout, 548, 554, 500, 60, T.fs(28), T.c.gold, "center", "display")
    end

    -- banner
    if self.banner then
        local b = self.banner
        local sc = T.opts.reducedMotion and 1 or E.backOut(T.clamp(b.t / 0.35, 0, 1))
        g.push()
        g.translate(PCX, 372)
        g.scale(sc, sc)
        T.set({ 0, 0, 0 }, 0.6)
        T.textBox(b.text, -297, -30, 594, 70, 60, { 0, 0, 0 }, "center", "display", 0.6)
        T.textBox(b.text, -300, -34, 600, 70, 60, b.color, "center", "display")
        if b.sub then T.text(b.sub, -300, 34, T.fs(16), T.c.text, "center", 600) end
        g.pop()
    end

    -- popups
    for _, p in ipairs(self.popups) do
        local f = p.age / p.life
        local a = 1 - f * f * f
        local py = p.y - f * 36
        T.set({ 0, 0, 0 }, 0.7 * a)
        T.textBox(p.text, p.x - 148, py + 2, 296, p.size * 1.5, p.size, { 0, 0, 0 }, "center", "display", 0.7 * a)
        T.textBox(p.text, p.x - 150, py, 300, p.size * 1.5, p.size, p.color, "center", "display", a)
    end

    self.act:draw()

    if self.hoverJoker and not self.paused then
        local s = self.jsprites[self.hoverJoker]
        C.tooltip(self.hoverJoker, s.x, s.y + 74)
    end

    if self.mode == "cashout" then self:drawCashout() end

    if self.paused then
        T.set(T.c.dark, 0.78)
        g.rectangle("fill", 0, 0, T.UI_W, T.UI_H)
        W.panel(472, 170, 336, 270, "PAUSED")
        T.text("Take a breather", 504, 202, T.fs(28), T.c.text, "left", nil, "display")
        self.pauseG:draw()
        local fx = 552
        fx = fx + T.keycap("Esc", fx, 400, 24) + 6
        T.text("Resume", fx, 403, T.fs(13), T.c.dim)
    end
end

function Table:drawCashout()
    local g = love.graphics
    T.set(T.c.dark, 0.72)
    g.rectangle("fill", 0, 0, T.UI_W, T.UI_H)
    local x, y, w, h = 440, 96, 400, 496
    W.panel(x, y, w, h)
    T.text("BLIND CLEARED", x, y + 22, T.fs(34), T.c.gold, "center", w, "display")
    T.text(self.blind.name, x, y + 66, T.fs(16), T.c.dim, "center", w)
    local shown = math.min(#self.cashLines, math.floor(self.cashT / (0.28 * math.max(speedF(), 0.2))))
    local ly = y + 108
    local running = 0
    for i = 1, shown do
        local l = self.cashLines[i]
        running = running + l.amount
        T.text(l.label, x + 28, ly, T.fs(16), T.c.text, "left", w - 120)
        T.text("+$" .. l.amount, x + 28, ly, T.fs(18), T.c.gold, "right", w - 56)
        ly = ly + 34
    end
    if shown >= #self.cashLines then
        T.set(T.c.line)
        g.rectangle("fill", x + 28, y + 352, w - 56, 2)
        T.text("Total", x + 28, y + 366, T.fs(22), T.c.text, "left", nil, "display")
        T.text("$" .. self.cashTotal, x + 28, y + 362, T.fs(30), T.c.gold, "right", w - 56, "display")
    end
    self.cashG:draw()
end

-- ---------------------------------------------------------------- input

function Table:keypressed(k, isrepeat)
    if k == "escape" then
        if self.mode ~= "cashout" and self.mode ~= "leaving" and not isrepeat then
            self:setPaused(not self.paused)
        end
        return
    end
    if self.paused then self.pauseG:keypressed(k) return end
    if self.mode == "cashout" then
        if k == "space" and not isrepeat then self:finishCash() return end
        self.cashG:keypressed(k)
        return
    end
    if not isrepeat then
        if k == "h" then self:doHit() return
        elseif k == "s" then self:doStand() return
        elseif k == "d" then self:doDouble() return
        elseif k == "space" and self.mode == "idle" then self:doDeal() return end
    end
    self.act:keypressed(k)
end

function Table:mousepressed(x, y, b)
    if b == 1 and not self.paused and self.mode ~= "cashout" and self.mode ~= "leaving"
        and self.round:deckPeekActive()
        and x >= DECK_X - C.CW * 0.55 and x <= DECK_X + C.CW * 0.55
        and y >= DECK_Y - C.CH * 0.55 and y <= DECK_Y + C.CH * 0.55 then
        self.deckPeekCard = self.round:useDeckPeek()
        self.deckPeekTimer = 2.5
        self:saveProgress()
        return
    end
    if b == 1 and not self.paused and self.mode ~= "cashout" and self.mode ~= "leaving"
        and (self.mode == "idle" or self.mode == "player") then
        for _, j in ipairs(self.run.jokers) do
            local s = self.jsprites[j]
            if Sprite.hit(s, x, y, C.JW, C.JH) then
                self.draggingJoker = j
                s.x, s.y, s.tx, s.ty = x, y, x, y
                return
            end
        end
    end
    if self.paused then self.pauseG:mousepressed(x, y, b)
    elseif self.mode == "cashout" then self.cashG:mousepressed(x, y, b)
    else self.act:mousepressed(x, y, b) end
end

function Table:mousereleased(x, y)
    if self.draggingJoker then
        local joker = self.draggingJoker
        self.draggingJoker = nil
        x, y = x or App.mx, y or App.my
        if y >= JOKER_Y - C.JH / 2 - 20 and y <= JOKER_Y + C.JH / 2 + 20 then
            local from, to
            for i, j in ipairs(self.run.jokers) do
                if j == joker then from = i end
            end
            if from then
                to = T.clamp(math.floor((x - JOKER_X0) / JOKER_SP + 1.5), 1, #self.run.jokers)
                if to ~= from then
                    table.remove(self.run.jokers, from)
                    table.insert(self.run.jokers, to, joker)
                    self:saveProgress()
                end
            end
        end
        for i, j in ipairs(self.run.jokers) do
            local s = self.jsprites[j]
            local slotX = JOKER_X0 + (i - 1) * JOKER_SP
            s.tx, s.ty = slotX, JOKER_Y
            s.trot = 0
        end
    end
    self.act:mousereleased()
    self.pauseG:mousereleased()
    self.cashG:mousereleased()
end

return Table
