local Blinds = require("game.blinds")
local Jokers = require("game.jokers")
local Save = require("game.save")

local Run = {}
Run.__index = Run
Run.cur = nil

Run.UPGRADES = {
    { id = "hand", name = "Extra Hand", desc = "+1 hand every blind",  cost = 10, max = 2 },
    { id = "slot", name = "Joker Slot", desc = "+1 joker slot",        cost = 8,  max = 2 },
}

function Run.new()
    local r = setmetatable({}, Run)
    r.ante, r.blindIdx = 1, 1
    r.money, r.hands, r.slots = 5, 4, 5
    r.jokers = {}
    r.bought = { hand = 0, slot = 0 }
    r.bosses = {}
    r.victory = false
    r.stats = { hands = 0, wins = 0, best = 0, blinds = 0 }
    r:rollBoss(1)
    Run.cur = r
    r:save()
    return r
end

function Run:save(roundState)
    local bosses = {}
    for ante, boss in pairs(self.bosses) do bosses[ante] = boss.key end
    local jokers = {}
    for i, j in ipairs(self.jokers) do jokers[i] = { id = j.id, state = j.state } end
    Save.writeRun({ ante = self.ante, blindIdx = self.blindIdx, money = self.money,
        hands = self.hands, slots = self.slots, jokers = jokers, bought = self.bought,
        bosses = bosses, victory = self.victory, stats = self.stats,
        shop = self.shop, round = roundState })
end

function Run.restore(state)
    if type(state) ~= "table" or not state.ante or not state.blindIdx then return nil end
    local r = setmetatable({}, Run)
    r.ante, r.blindIdx = state.ante, state.blindIdx
    r.money, r.hands, r.slots = state.money or 0, state.hands or 4, state.slots or 5
    r.jokers, r.bought, r.bosses = {}, state.bought or { hand = 0, slot = 0 }, {}
    for _, saved in ipairs(state.jokers or {}) do
        if Jokers.byId[saved.id] then
            local j = Jokers.new(saved.id)
            j.state = saved.state or {}
            r.jokers[#r.jokers + 1] = j
        end
    end
    for ante, key in pairs(state.bosses or {}) do
        for _, boss in ipairs(Blinds.BOSSES) do
            if boss.key == key then r.bosses[tonumber(ante) or ante] = boss break end
        end
    end
    r.victory, r.stats, r.shop = state.victory or false,
        state.stats or { hands = 0, wins = 0, best = 0, blinds = 0 }, state.shop
    if not r.bosses[r.ante] then r:rollBoss(r.ante) end
    Run.cur = r
    return r
end

function Run:rollBoss(ante)
    self.bosses[ante] = Blinds.BOSSES[math.random(1, #Blinds.BOSSES)]
end

function Run:blindFor(idx)
    return Blinds.make(self.ante, idx, self.bosses[self.ante])
end

function Run:currentBlind() return self:blindFor(self.blindIdx) end

function Run:blindList()
    return { self:blindFor(1), self:blindFor(2), self:blindFor(3) }
end

function Run:advance()
    self.blindIdx = self.blindIdx + 1
    if self.blindIdx > 3 then
        self.blindIdx = 1
        self.ante = self.ante + 1
        if self.ante > Blinds.ANTES then
            self.victory = true
        else
            self:rollBoss(self.ante)
        end
    end
    self:save()
end

function Run:skipBlind()
    if self.blindIdx >= 3 then return false end
    self.money = self.money + Blinds.SKIP_BONUS
    self:advance()
    return true
end

-- Returns the itemised payout for clearing `round` and applies it.
function Run:cashOut(round)
    local lines = {}
    local function add(label, amt)
        if amt and amt > 0 then lines[#lines + 1] = { label = label, amount = amt } end
    end
    add(round.blind.name .. " reward", round.blind.reward)
    add("Unused hands (" .. round.handsLeft .. " x $1)", round.handsLeft)
    for _, j in ipairs(self.jokers) do
        if j.def.onBlindEnd then add(j.def.name, j.def.onBlindEnd(self, j)) end
    end
    add("Interest ($1 per $5)", math.min(5, math.floor(self.money / 5)))
    local total = 0
    for _, l in ipairs(lines) do total = total + l.amount end
    self.money = self.money + total
    self.stats.blinds = self.stats.blinds + 1
    self:save()
    return lines, total
end

-- ------------------------------------------------------------------ shop

local WEIGHT = { 60, 30, 10, 5 }

function Run:owns(id)
    for _, j in ipairs(self.jokers) do
        if j.id == id then return true end
    end
    return false
end

function Run:fillOffers()
    local offers = {}
    for _ = 1, 3 do
        local pool, total = {}, 0
        for _, d in ipairs(Jokers.list) do
            local taken = self:owns(d.id)
            for _, o in ipairs(offers) do
                if o == d.id then taken = true end
            end
            if not taken then
                pool[#pool + 1] = d
                total = total + WEIGHT[d.rarity]
            end
        end
        if #pool == 0 then break end
        local roll, pick = math.random() * total, pool[#pool]
        for _, d in ipairs(pool) do
            roll = roll - WEIGHT[d.rarity]
            if roll <= 0 then pick = d break end
        end
        offers[#offers + 1] = pick.id
    end
    self.shop.offers = offers
end

function Run:genShop()
    self.shop = { offers = {}, rerollCost = 2 }
    self:fillOffers()
    self:save()
end

function Run:canBuyJoker(id)
    local d = Jokers.byId[id]
    return d and self.money >= d.cost and #self.jokers < self.slots
end

function Run:buyJoker(index)
    local id = self.shop.offers[index]
    if not id or not self:canBuyJoker(id) then return false end
    self.money = self.money - Jokers.byId[id].cost
    self.jokers[#self.jokers + 1] = Jokers.new(id)
    table.remove(self.shop.offers, index)
    self:save()
    return true
end

function Run:sell(inst)
    for i, j in ipairs(self.jokers) do
        if j == inst then
            self.money = self.money + Jokers.sellValue(inst)
            table.remove(self.jokers, i)
            self:save()
            return true
        end
    end
    return false
end

function Run:upgradeAvailable(u)
    return self.bought[u.id] < u.max
end

function Run:buyUpgrade(id)
    for _, u in ipairs(Run.UPGRADES) do
        if u.id == id and self:upgradeAvailable(u) and self.money >= u.cost then
            self.money = self.money - u.cost
            self.bought[id] = self.bought[id] + 1
            if id == "hand" then self.hands = self.hands + 1 end
            if id == "slot" then self.slots = self.slots + 1 end
            self:save()
            return true
        end
    end
    return false
end

function Run:reroll()
    if self.money < self.shop.rerollCost then return false end
    self.money = self.money - self.shop.rerollCost
    self.shop.rerollCost = self.shop.rerollCost + 1
    self:fillOffers()
    self:save()
    return true
end

return Run
