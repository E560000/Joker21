local T = require("ui.theme")
local W = require("ui.widgets")
local C = require("ui.cardart")
local App = require("app")

local Howto = {}

local RULES = {
    GOAL = { "THE GOAL", "Each blind has a target score. Reach it before you run out of hands. " ..
        "Clear a Small, Big and Boss blind to finish an ante. Survive 8 antes to win." },
    HAND = { "EACH HAND", "Play blackjack against the dealer (dealer stands on 17). Hit to draw, " ..
        "Stand to stop, or Double to draw exactly one card for double score. A dealer Blackjack " ..
        "automatically ends a hand you cannot win." },
    SCORING = { "SCORING", "Win a hand and it scores CHIPS x MULT. Chips = 10 + the chip value of each " ..
        "of your cards (Ace 11, faces 10). Mult starts at 1: +3 for a Blackjack, " ..
        "+1 for 21, +1 if the dealer busts." },
    MISSES = { "MISSES", "Lose or bust and the hand scores nothing but still uses a hand. " ..
        "A push scores nothing and gives the hand back. Doubling costs 2 hands." },
    JOKERS = { "JOKERS", "Buy jokers in the shop to add chips, mult and X mult. Drag jokers across the " ..
        "row to reorder their scoring effects. Sell any joker for half its price." },
    BOSSES = { "BOSSES", "Every ante ends with a boss that bends a rule. Read it before you play." },
}

-- Each tab is either a list of rule sections (stacked panels) or a custom draw function.
local TABS = {
    { name = "Basics",          sections = { RULES.GOAL, RULES.HAND } },
    { name = "Scoring",         sections = { RULES.SCORING, RULES.MISSES } },
    { name = "Jokers & Bosses", sections = { RULES.JOKERS, RULES.BOSSES } },
    { name = "Example",         example = true },
}

-- Tab bar layout
local TAB_X, TAB_Y, TAB_W, TAB_H, TAB_GAP = 60, 84, 220, 38, 8
-- Content area
local CX, CY, CW = 60, 134, 1160

local function tabRect(i)
    return TAB_X + (i - 1) * (TAB_W + TAB_GAP), TAB_Y, TAB_W, TAB_H
end

local function inRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function Howto:setTab(i)
    self.tab = ((i - 1) % #TABS) + 1
    self.tabT = 0
end

function Howto:enter()
    self.t = 0
    self.tab = 1
    self.tabT = 0
    local g = W.group()
    self.g = g
    g:add(W.button { x = 60, y = 650, w = 200, h = 54, label = "Back", icon = "back",
        onClick = function() App.go("menu") end })
    g.focus = 1
end

function Howto:update(dt)
    self.t = self.t + dt
    self.tabT = self.tabT + dt
    self.g:update(dt, App.mx, App.my)
end

local function miniCard(rank, suit, x, y)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(0.62, 0.62)
    C.face({ rank = rank, suit = suit }, C.CW, C.CH)
    love.graphics.pop()
end

function Howto:drawTabs()
    -- baseline under the whole tab bar
    T.set(T.c.line)
    love.graphics.rectangle("fill", CX, TAB_Y + TAB_H, CW, 2)

    for i, tab in ipairs(TABS) do
        local x, y, w, h = tabRect(i)
        local active = (i == self.tab)
        local hover = inRect(App.mx or -1, App.my or -1, x, y, w, h)

        if active then
            T.set(T.c.gold)
            love.graphics.rectangle("fill", x, y + h - 3, w, 5)
        elseif hover then
            T.set(T.c.line)
            love.graphics.rectangle("fill", x, y + h - 3, w, 4)
        end

        T.textBox(tab.name, x, y, w, h - 2, T.fs(18),
            active and T.c.gold or (hover and T.c.text or T.c.dim), "center")
    end
end

function Howto:drawSections(sections)
    -- Stacked full-width panels, larger text since there's more room per tab
    local gap = 20
    local h = 230
    for i, r in ipairs(sections) do
        local y = CY + 10 + (i - 1) * (h + gap)
        W.panel(CX, y, CW, h, r[1])
        T.text(r[2], CX + 30, y + 56, T.fs(24), T.c.text, "left", CW - 60)
    end
end

function Howto:drawExample()
    local pw, ph = 340, 510
    local px, py = CX + (CW - pw) / 2, CY - 4
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
end

function Howto:draw()
    T.text("How to Play", 60, 26, 44, T.c.text, "left", nil, "display")

    self:drawTabs()

    local tab = TABS[self.tab]
    if tab.example then
        self:drawExample()
    else
        self:drawSections(tab.sections)
    end

    self.g:draw()

    -- footer key hints
    local fx = 300
    fx = fx + T.keycap("Esc", fx, 655, 24) + 6
    T.text("Back", fx, 658, T.fs(13), T.c.dim)
    fx = 420
    fx = fx + T.keycap("Q", fx, 655, 24) + 4
    fx = fx + T.keycap("E", fx, 655, 24) + 6
    T.text("Switch tab", fx, 658, T.fs(13), T.c.dim)
end

function Howto:keypressed(k)
    if k == "escape" then App.go("menu") return end
    if k == "left" or k == "q" then self:setTab(self.tab - 1) return end
    if k == "right" or k == "e" then self:setTab(self.tab + 1) return end
    local n = tonumber(k)
    if n and TABS[n] then self:setTab(n) return end
    self.g:keypressed(k)
end

function Howto:mousepressed(x, y, b)
    if b == 1 then
        for i = 1, #TABS do
            local tx, ty, tw, th = tabRect(i)
            if inRect(x, y, tx, ty, tw, th) then
                self:setTab(i)
                return
            end
        end
    end
    self.g:mousepressed(x, y, b)
end

function Howto:mousereleased() self.g:mousereleased() end

return Howto
