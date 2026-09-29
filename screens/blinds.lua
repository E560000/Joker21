-- screens/blinds.lua  -  ante overview: pick or skip the current blind

local T = require("ui.theme")
local W = require("ui.widgets")
local E = require("lib.easing")
local C = require("ui.cardart")
local Sprite = require("ui.sprite")
local Blinds = require("game.blinds")
local Run = require("game.run")
local App = require("app")
local Audio = require("game.audio")

local Screen = {}

local CARD_W, CARD_H = 300, 390
local XS = { 100, 490, 880 }
local CY = 130

local TYPE_COL = {
    { 0.45, 0.70, 1.00 }, { 1.00, 0.72, 0.25 }, { 1.00, 0.35, 0.38 },
}

function Screen:enter()
    self.run = Run.cur
    self.t = 0
    self.list = self.run:blindList()
    self.idx = self.run.blindIdx
    self.jsprites = {}
    local g = W.group()
    self.g = g
    local x = XS[self.idx]
    self.play = g:add(W.button { x = x + 20, y = CY + CARD_H - 112, w = CARD_W - 40, h = 52,
        label = "Play Blind", icon = "play", primary = true,
        onClick = function() Audio.play("blind_select"); App.go("table", "iris") end })
    self.skip = g:add(W.button { x = x + 20, y = CY + CARD_H - 52, w = CARD_W - 40, h = 40,
        label = "Skip  (+$" .. Blinds.SKIP_BONUS .. ")", size = 16, icon = "next", iconSize = 8,
        hidden = (self.idx >= 3),
        onClick = function()
            self.run:skipBlind()
            if self.run.victory then App.go("gameover", "fade", { victory = true })
            else App.go("blinds", "fade") end
        end })
    g:add(W.button { x = 60, y = 640, w = 200, h = 54, label = "Menu", icon = "back",
        onClick = function() App.go("menu") end })
    g.focus = 1
    g:playIntro(0.06)
    for i, j in ipairs(self.run.jokers) do
        local s = Sprite.new(112 + (i - 1) * 84, 588)
        s.sc, s.tsc = 0.7, 0.7
        self.jsprites[j] = s
    end
end

function Screen:update(dt)
    self.t = self.t + dt
    self.g:update(dt, App.mx, App.my)
    self.hoverJoker = nil
    for _, j in ipairs(self.run.jokers) do
        local s = self.jsprites[j]
        local hov = Sprite.hit(s, App.mx, App.my, C.JW * 0.7, C.JH * 0.7)
        s.thover = hov and 1 or 0
        if hov then self.hoverJoker = j end
        Sprite.update(s, dt)
    end
end

local function blindCard(self, i, b)
    local g = love.graphics
    local x = XS[i]
    local state = (i < self.idx) and "done" or ((i == self.idx) and "current" or "later")
    local e = E.cubicOut(T.clamp((self.t - (i - 1) * 0.08) / 0.5, 0, 1))
    if T.opts.reducedMotion then e = 1 end
    local rise = 0
    g.push()
    g.translate(0, (1 - e) * 60 + rise)
    local prev = T.alpha
    T.alpha = prev * e * ((state == "current") and 1 or 0.55)

    local col = TYPE_COL[i]
    W.panel(x, CY, CARD_W, CARD_H)
    if state == "current" then
        g.setLineWidth(3)
        T.set(col)
        g.rectangle("line", x, CY, CARD_W, CARD_H, 14, 14)
    end
    T.set(col, 0.85)
    g.rectangle("fill", x + 16, CY + 16, CARD_W - 32, 6, 3, 3)
    T.text(b.name, x, CY + 34, T.fs(30), T.c.text, "center", CARD_W, "display")
    T.spaced((i == 3) and "BOSS" or ((i == 2) and "BIG" or "SMALL"), x + CARD_W / 2 - 24, CY + 76,
        T.fs(12), col, 4)

    T.text("SCORE AT LEAST", x, CY + 108, T.fs(12), T.c.dim, "center", CARD_W)
    g.setColor(T.c.chips[1], T.c.chips[2], T.c.chips[3], T.alpha)
    g.circle("fill", x + 60, CY + 152, 14)
    T.set(T.c.dark)
    g.circle("fill", x + 60, CY + 152, 8)
    T.text(T.commas(b.target), x + 30, CY + 130, T.fs(40), T.c.text, "center", CARD_W - 30, "display")

    T.text("REWARD", x, CY + 194, T.fs(12), T.c.dim, "center", CARD_W)
    T.text(string.rep("$", b.reward), x, CY + 210, T.fs(28), T.c.gold, "center", CARD_W, "display")

    if b.boss then
        T.set(T.c.bad, 0.16)
        g.rectangle("fill", x + 16, CY + 252, CARD_W - 32, 56, 8, 8)
        T.text(b.boss.desc, x + 28, CY + 262, T.fs(14), T.c.text, "center", CARD_W - 56)
    end

    if state == "done" then
        T.set(T.c.ok, 0.9)
        g.setLineWidth(6)
        g.line(x + CARD_W / 2 - 22, CY + 330, x + CARD_W / 2 - 6, CY + 348, x + CARD_W / 2 + 26, CY + 312)
        T.text("CLEARED", x, CY + 356, T.fs(14), T.c.ok, "center", CARD_W)
    elseif state == "later" then
        T.text("UPCOMING", x, CY + 356, T.fs(14), T.c.dim, "center", CARD_W)
    end
    T.alpha = prev
    g.pop()
end

function Screen:draw()
    local run = self.run
    T.text("Ante " .. run.ante, 60, 26, 44, T.c.text, "left", nil, "display")
    T.text("of " .. #require("game.blinds").BASE, 60 + T.font("display", 44):getWidth("Ante " .. run.ante) + 14,
        44, T.fs(20), T.c.dim)
    T.text("Choose your blind", 62, 88, T.fs(16), T.c.dim)

    W.panel(1000, 22, 220, 74)
    T.spaced("MONEY", 1020, 32, T.fs(11), T.c.dim, 3)
    T.text("$" .. run.money, 1020, 50, T.fs(34), T.c.gold, "left", nil, "display")
    W.panel(770, 22, 214, 74)
    T.spaced("HANDS / BLIND", 790, 32, T.fs(11), T.c.dim, 3)
    T.text(tostring(run.hands), 790, 50, T.fs(34), T.c.chips, "left", nil, "display")

    for i, b in ipairs(self.list) do blindCard(self, i, b) end
    self.g:draw()

    -- owned jokers
    W.panel(60, 538, 1160, 96, nil)
    T.spaced("JOKERS " .. #run.jokers .. "/" .. run.slots, 1030, 552, T.fs(12), T.c.dim, 3)
    if #run.jokers == 0 then
        T.text("No jokers yet - buy some in the shop after your first blind.", 84, 578, T.fs(15), T.c.dim)
    end
    for _, j in ipairs(run.jokers) do
        local s = self.jsprites[j]
        Sprite.draw(s, function() C.joker(j.def) end, function() C.back() end)
    end
    if self.hoverJoker then
        local s = self.jsprites[self.hoverJoker]
        C.tooltip(self.hoverJoker, s.x, s.y - 175)
    end
end

function Screen:keypressed(k)
    if k == "escape" then App.go("menu") return end
    self.g:keypressed(k)
end
function Screen:mousepressed(x, y, b) self.g:mousepressed(x, y, b) end
function Screen:mousereleased() self.g:mousereleased() end

return Screen
