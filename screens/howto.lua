-- screens/howto.lua  -  rules + a worked scoring example

local T = require("ui.theme")
local W = require("ui.widgets")
local C = require("ui.cardart")
local App = require("app")

local Howto = {}

local RULES = {
    { "THE GOAL", "Each blind has a target score. Reach it before you run out of hands. " ..
        "Clear a Small, Big and Boss blind to finish an ante. Survive 8 antes to win." },
    { "EACH HAND", "Play blackjack against the dealer (dealer stands on 17). Hit to draw, " ..
        "Stand to stop, or Double to draw exactly one card for double score. A dealer Blackjack " ..
        "automatically ends a hand you cannot win." },
    { "SCORING", "Win a hand and it scores CHIPS x MULT. Chips = 10 + the chip value of each " ..
        "of your cards (Ace 11, faces 10). Mult starts at 1: +3 for a Blackjack, " ..
        "+1 for 21, +1 if the dealer busts." },
    { "MISSES", "Lose or bust and the hand scores nothing but still uses a hand. " ..
        "A push scores nothing and gives the hand back. Doubling costs 2 hands." },
    { "JOKERS", "Buy jokers in the shop to add chips, mult and X mult. Drag jokers across the " ..
        "row to reorder their scoring effects. Sell any joker for half its price." },
    { "BOSSES", "Every ante ends with a boss that bends a rule. Read it before you play." },
}

function Howto:enter()
    self.t = 0
    local g = W.group()
    self.g = g
    g:add(W.button { x = 60, y = 640, w = 200, h = 54, label = "Back", icon = "back",
        onClick = function() App.go("menu") end })
    g.focus = 1
end

function Howto:update(dt)
    self.t = self.t + dt
    self.g:update(dt, App.mx, App.my)
end

local function miniCard(rank, suit, x, y)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(0.62, 0.62)
    C.face({ rank = rank, suit = suit }, C.CW, C.CH)
    love.graphics.pop()
end

function Howto:draw()
    T.text("How to Play", 60, 26, 44, T.c.text, "left", nil, "display")

    -- rules (two columns)
    for i, r in ipairs(RULES) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x, y, w, h = 60 + col * 400, 100 + row * 178, 380, 166
        W.panel(x, y, w, h, r[1])
        T.text(r[2], x + 20, y + 46, T.fs(15), T.c.text, "left", w - 40)
    end

    -- worked example
    local px, py, pw, ph = 880, 100, 340, 522
    W.panel(px, py, pw, ph, "EXAMPLE")
    miniCard("K", "S", px + 62, py + 106)
    miniCard("7", "H", px + 128, py + 106)
    miniCard("4", "D", px + 194, py + 106)
    T.text("Your hand: 21 vs dealer 19", px + 20, py + 168, T.fs(14), T.c.dim, "left", pw - 40)

    local lines = {
        { "Base", "+10", T.c.chips },
        { "K", "+10", T.c.chips },
        { "7", "+7", T.c.chips },
        { "4", "+4", T.c.chips },
        { "Twenty-One", "+1 Mult", T.c.mult },
    }
    for i, l in ipairs(lines) do
        local y = py + 208 + (i - 1) * 30
        T.text(l[1], px + 24, y, T.fs(16), T.c.text)
        T.text(l[2], px + 24, y, T.fs(16), l[3], "right", pw - 48)
    end
    T.set(T.c.line)
    love.graphics.rectangle("fill", px + 24, py + 366, pw - 48, 2)
    local bx = px + 24
    T.set(T.c.chips)
    W.panel(bx, py + 382, 130, 60)
    T.textBox("31", bx, py + 382, 130, 60, T.fs(34), T.c.chips, "center", "display")
    T.textBox("x", bx + 130, py + 382, 40, 60, T.fs(28), T.c.text, "center")
    W.panel(bx + 170, py + 382, 130, 60)
    T.textBox("2", bx + 170, py + 382, 130, 60, T.fs(34), T.c.mult, "center", "display")
    T.textBox("= 62 points", px, py + 456, pw, 40, T.fs(24), T.c.gold, "center", "display")

    self.g:draw()
    local fx = 300
    fx = fx + T.keycap("Esc", fx, 655, 24) + 6
    T.text("Back", fx, 658, T.fs(13), T.c.dim)
end

function Howto:keypressed(k)
    if k == "escape" then App.go("menu") return end
    self.g:keypressed(k)
end
function Howto:mousepressed(x, y, b) self.g:mousepressed(x, y, b) end
function Howto:mousereleased() self.g:mousereleased() end

return Howto
