local T = require("ui.theme")
local W = require("ui.widgets")
local E = require("lib.easing")
local C = require("ui.cardart")
local Jokers = require("game.jokers")
local Run = require("game.run")
local App = require("app")
local Audio = require("game.audio")

local Shop = {}

local OFFER_X = { 145, 360, 575 }
local OFFER_Y = 240
local OFFER_SC = 1.25

function Shop:enter()
    self.run = Run.cur
    self.t = 0
    self.selected = nil
    self.hoverOffer, self.hoverOwned = nil, nil
    local run = self.run
    local g = W.group()
    self.g = g

    self.buy = {}
    for i = 1, 3 do
        self.buy[i] = g:add(W.button { x = OFFER_X[i] - 75, y = 368, w = 150, h = 44, label = "Buy",
            size = 18, primary = true, onClick = function()
                if run:buyJoker(i) then
                    Audio.play("joker_buy")
                    self.selected = nil
                    self:refresh()
                end
            end })
    end
    self.up = {}
    for i, u in ipairs(Run.UPGRADES) do
        self.up[i] = g:add(W.button { x = 724, y = 150 + (i - 1) * 104, w = 492, h = 90, label = u.name,
            sub = u.desc, size = 22, onClick = function()
                if run:buyUpgrade(u.id) then self:refresh() end
            end })
    end
    self.reroll = g:add(W.button { x = 724, y = 364, w = 492, h = 52, label = "Reroll jokers", icon = "restart",
        size = 20, onClick = function()
            if run:reroll() then self:refresh() end
        end })
    self.sell = g:add(W.button { x = 1030, y = 538, w = 170, h = 44, label = "Sell", size = 18,
        danger = true, hidden = true, onClick = function()
            if self.selected and run:sell(self.selected) then
                Audio.play("joker_sell")
                self.selected = nil
                self:refresh()
            end
        end })
    self.nextBtn = g:add(W.button { x = 1020, y = 640, w = 220, h = 56, label = "Next Blind", icon = "next",
        primary = true, onClick = function() App.go("blinds", "fade") end })
    self:refresh()
    g.focus = #g.items
    g:playIntro(0.04)
end

function Shop:refresh()
    local run = self.run
    for i = 1, 3 do
        local id = run.shop.offers[i]
        local b = self.buy[i]
        b.hidden = (id == nil)
        if id then
            b.label = "Buy  $" .. Jokers.byId[id].cost
            b.enabled = run:canBuyJoker(id)
        end
    end
    for i, u in ipairs(Run.UPGRADES) do
        local b = self.up[i]
        local left = u.max - run.bought[u.id]
        b.label = u.name .. "  -  $" .. u.cost
        b.sub = (left > 0) and (u.desc .. "   (" .. left .. " left)") or "Sold out"
        b.enabled = (left > 0) and run.money >= u.cost
    end
    self.reroll.label = "Reroll jokers  -  $" .. run.shop.rerollCost
    self.reroll.enabled = run.money >= run.shop.rerollCost
    if self.selected then
        self.sell.hidden = false
        self.sell.label = "Sell  +$" .. Jokers.sellValue(self.selected)
    else
        self.sell.hidden = true
    end
end

function Shop:ownedPos(i)
    return 120 + (i - 1) * 112, 592
end

function Shop:update(dt)
    self.t = self.t + dt
    self.g:update(dt, App.mx, App.my)
    self.hoverOffer, self.hoverOwned = nil, nil
    local mx, my = App.mx, App.my
    for i, id in ipairs(self.run.shop.offers) do
        local cx = OFFER_X[i]
        if math.abs(mx - cx) <= C.JW * OFFER_SC / 2 and math.abs(my - OFFER_Y) <= C.JH * OFFER_SC / 2 then
            self.hoverOffer = i
        end
    end
    for i, j in ipairs(self.run.jokers) do
        local x, y = self:ownedPos(i)
        if math.abs(mx - x) <= C.JW / 2 and math.abs(my - y) <= C.JH / 2 then
            self.hoverOwned = j
        end
    end
end

function Shop:draw()
    local g = love.graphics
    local run = self.run
    T.text("Shop", 60, 26, 44, T.c.text, "left", nil, "display")
    T.text("Ante " .. run.ante .. " - next up: " .. require("game.blinds").NAMES[run.blindIdx],
        62, 84, T.fs(16), T.c.dim)

    W.panel(1000, 22, 220, 74)
    T.spaced("MONEY", 1020, 32, T.fs(11), T.c.dim, 3)
    T.text("$" .. run.money, 1020, 50, T.fs(34), T.c.gold, "left", nil, "display")

    W.panel(40, 110, 660, 320, "JOKERS FOR SALE")
    W.panel(708, 110, 528, 320, "UPGRADES")
    W.panel(40, 442, 1200, 180, "YOUR JOKERS  " .. #run.jokers .. "/" .. run.slots)

    for i, id in ipairs(run.shop.offers) do
        local def = Jokers.byId[id]
        local e = E.cubicOut(T.clamp((self.t - (i - 1) * 0.08) / 0.45, 0, 1))
        if T.opts.reducedMotion then e = 1 end
        local hov = (self.hoverOffer == i)
        g.push()
        g.translate(OFFER_X[i], OFFER_Y + (1 - e) * 50 - (hov and 8 or 0))
        g.scale(OFFER_SC, OFFER_SC)
        local prev = T.alpha
        T.alpha = prev * e
        C.joker(def)
        T.alpha = prev
        g.pop()
    end
    if #run.shop.offers == 0 then
        T.text("Sold out - reroll for new offers.", 60, 220, T.fs(18), T.c.dim, "center", 620)
    end

    for i, j in ipairs(run.jokers) do
        local x, y = self:ownedPos(i)
        local sel = (self.selected == j)
        g.push()
        g.translate(x, y - ((sel or self.hoverOwned == j) and 8 or 0))
        C.joker(j.def)
        g.pop()
        if sel then
            g.setLineWidth(3)
            T.set(T.c.accent)
            T.rrect("line", x - C.JW / 2 - 4, y - C.JH / 2 - 12, C.JW + 8, C.JH + 8, 12)
        end
    end
    if #run.jokers == 0 then
        T.text("You own no jokers yet.", 60, 570, T.fs(18), T.c.dim)
    else
        T.text("Click a joker to select it, then sell it for half price.", 690, 470, T.fs(13), T.c.dim, "right", 520)
    end

    self.g:draw()

    if self.hoverOffer then
        local id = run.shop.offers[self.hoverOffer]
        local inst = Jokers.new(id)
        C.tooltip(inst, OFFER_X[self.hoverOffer], OFFER_Y + 110)
    elseif self.hoverOwned then
        local i
        for k, j in ipairs(run.jokers) do if j == self.hoverOwned then i = k end end
        local x = self:ownedPos(i)
        C.tooltip(self.hoverOwned, x, 448, "Sells for $" .. Jokers.sellValue(self.hoverOwned))
    end
end

function Shop:keypressed(k)
    if k == "escape" then return end
    self.g:keypressed(k)
end

function Shop:mousepressed(x, y, b)
    if self.g:mousepressed(x, y, b) then return end
    if b == 1 then
        if self.hoverOwned then
            self.selected = (self.selected == self.hoverOwned) and nil or self.hoverOwned
            self:refresh()
        else
            self.selected = nil
            self:refresh()
        end
    end
end

function Shop:mousereleased() self.g:mousereleased() end

return Shop
