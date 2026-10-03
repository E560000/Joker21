-- ui/cardart.lua
-- Everything on a card is drawn with shapes (no image assets). All draw
-- functions are centred on (0,0) so a sprite can translate/rotate/scale them.

local T = require("ui.theme")
local J = require("game.jokers")

local C = {}
C.CW, C.CH = 100, 140   -- playing card size
C.JW, C.JH = 88, 122    -- joker card size

local function rr(mode, x, y, w, h, r)
    love.graphics.rectangle(mode, x, y, w, h, r, r)
end

-- Suit symbol centred at (cx, cy), roughly fitting radius r.
function C.suit(s, cx, cy, r, color, alpha)
    local g = love.graphics
    T.set(color, alpha)
    if s == "D" then
        g.polygon("fill", cx, cy - r, cx + r * 0.72, cy, cx, cy + r, cx - r * 0.72, cy)
    elseif s == "H" then
        g.circle("fill", cx - r * 0.5, cy - r * 0.3, r * 0.56)
        g.circle("fill", cx + r * 0.5, cy - r * 0.3, r * 0.56)
        g.polygon("fill", cx - r * 1.03, cy - r * 0.05, cx + r * 1.03, cy - r * 0.05, cx, cy + r)
    elseif s == "S" then
        g.circle("fill", cx - r * 0.5, cy + r * 0.2, r * 0.56)
        g.circle("fill", cx + r * 0.5, cy + r * 0.2, r * 0.56)
        g.polygon("fill", cx - r * 1.03, cy + r * 0.1, cx + r * 1.03, cy + r * 0.1, cx, cy - r)
        g.polygon("fill", cx, cy + r * 0.3, cx - r * 0.32, cy + r, cx + r * 0.32, cy + r)
    else -- clubs
        g.circle("fill", cx, cy - r * 0.5, r * 0.5)
        g.circle("fill", cx - r * 0.55, cy + r * 0.25, r * 0.5)
        g.circle("fill", cx + r * 0.55, cy + r * 0.25, r * 0.5)
        g.polygon("fill", cx, cy, cx - r * 0.32, cy + r, cx + r * 0.32, cy + r)
    end
end

local function shadow(w, h, lift)
    T.set({ 0, 0, 0 }, 0.28)
    rr("fill", -w / 2 + 3, -h / 2 + 6 + (lift or 0), w, h, 10)
end

-- ------------------------------------------------------------- playing cards

function C.face(card, w, h)
    w, h = w or C.CW, h or C.CH
    local g = love.graphics
    shadow(w, h)
    T.set({ 0.97, 0.95, 0.90 })
    rr("fill", -w / 2, -h / 2, w, h, 10)
    g.setLineWidth(2)
    T.set({ 0.25, 0.22, 0.20 })
    rr("line", -w / 2, -h / 2, w, h, 10)

    local ink = T.suitColor(card.suit)
    local isFace = (card.rank == "J" or card.rank == "Q" or card.rank == "K")
    local rs = h * 0.16
    local f = T.font("display", rs)
    T.setFont(f)
    T.set(ink)
    T.print(card.rank, -w / 2 + 8, -h / 2 + 4)
    C.suit(card.suit, -w / 2 + 8 + f:getWidth(card.rank) / 2, -h / 2 + rs + 16, w * 0.075, ink)
    -- bottom-right mirrored index
    g.push()
    g.rotate(math.pi)
    T.set(ink)
    T.print(card.rank, -w / 2 + 8, -h / 2 + 4)
    C.suit(card.suit, -w / 2 + 8 + f:getWidth(card.rank) / 2, -h / 2 + rs + 16, w * 0.075, ink)
    g.pop()

    if isFace then
        T.set(ink, 0.10)
        rr("fill", -w * 0.26, -h * 0.27, w * 0.52, h * 0.54, 8)
        C.suit(card.suit, 0, 0, w * 0.26, ink, 0.28)
        T.setFont(T.font("display", h * 0.34))
        T.set(ink)
        T.printf(card.rank, -w / 2, -h * 0.20, w, "center")
    elseif card.rank == "A" then
        C.suit(card.suit, 0, 0, w * 0.34, ink)
    else
        C.suit(card.suit, 0, 0, w * 0.22, ink)
    end
end

function C.back(w, h)
    w, h = w or C.CW, h or C.CH
    local g = love.graphics
    shadow(w, h)
    T.set({ 0.85, 0.30, 0.20 })
    rr("fill", -w / 2, -h / 2, w, h, 10)
    T.set({ 0.97, 0.95, 0.90 })
    g.setLineWidth(2)
    rr("line", -w / 2 + 6, -h / 2 + 6, w - 12, h - 12, 7)
    -- diamond lattice, clipped to the inner frame with the stencil buffer
    g.stencil(function() rr("fill", -w / 2 + 6, -h / 2 + 6, w - 12, h - 12, 7) end, "replace", 1)
    g.setStencilTest("greater", 0)
    T.set({ 1, 0.85, 0.6 }, 0.35)
    g.setLineWidth(1.5)
    local s = 18
    for i = -6, 6 do
        g.line(i * s - 40, -h / 2, i * s + 40, h / 2)
        g.line(i * s + 40, -h / 2, i * s - 40, h / 2)
    end
    g.setStencilTest()
    T.set({ 0.85, 0.30, 0.20 })
    g.circle("fill", 0, 0, 16)
    T.set({ 0.97, 0.95, 0.90 })
    g.circle("line", 0, 0, 16)
    C.suit("S", 0, 0, 8, { 0.97, 0.95, 0.90 })
end

-- ------------------------------------------------------------- joker cards

local RARITY_COL = { { 0.42, 0.62, 0.95 }, { 0.72, 0.45, 0.95 }, { 1.00, 0.70, 0.20 }, { 1.00, 0.35, 0.38 } }

function C.rarityColor(r) return RARITY_COL[r] or RARITY_COL[1] end

function C.joker(def, w, h, state)
    w, h = w or C.JW, h or C.JH
    local g = love.graphics
    local col = C.rarityColor(def.rarity)
    shadow(w, h)
    T.set({ 0.11, 0.13, 0.19 })
    rr("fill", -w / 2, -h / 2, w, h, 10)
    g.setLineWidth(2.5)
    T.set(col)
    rr("line", -w / 2, -h / 2, w, h, 10)
    -- banner
    T.set(col, 0.22)
    rr("fill", -w / 2 + 5, -h / 2 + 5, w - 10, h * 0.5, 7)
    -- emblem
    local cy = -h * 0.20
    if def.suit then
        local ink = def.suit == "S" and { 0.75, 0.80, 0.95 } or T.suitColor(def.suit)
        if def.suit == "S" then ink = { 0.75, 0.80, 0.95 } end
        C.suit(def.suit, 0, cy, w * 0.20, ink)
    else
        local f = T.font("display", (#def.art > 1) and h * 0.22 or h * 0.32)
        T.setFont(f)
        T.set(col)
        T.printf(def.art, -w / 2, cy - f:getHeight() / 2, w, "center")
    end
    -- name
    T.textBox(def.name, -w / 2 + 4, h * 0.11, w - 8, h * 0.25, 12, T.c.text, "center")
    -- rarity pips
    for i = 1, def.rarity do
        T.set(col)
        g.circle("fill", (i - (def.rarity + 1) / 2) * 10, h * 0.42, 3)
    end
    if state and state.dim then
        T.set({ 0, 0, 0 }, 0.45)
        rr("fill", -w / 2, -h / 2, w, h, 10)
    end
end

function C.jokerSlot(w, h)
    w, h = w or C.JW, h or C.JH
    love.graphics.setLineWidth(2)
    T.set(T.c.line, 0.55)
    rr("line", -w / 2, -h / 2, w, h, 10)
    T.set(T.c.line, 0.20)
    rr("fill", -w / 2, -h / 2, w, h, 10)
end

-- ------------------------------------------------------------- tooltip

-- Draws a tooltip box for a joker instance near (x, y) (screen space).
function C.tooltip(inst, x, y, extra)
    local d = inst.def
    local text = J.describe(inst)
    local w = 250
    local f = T.font("body", T.fs(15))
    local _, lines = f:getWrap(text, w - 28)
    local h = 64 + #lines * f:getHeight() + (extra and 26 or 0)
    x = T.clamp(x - w / 2, 8, T.UI_W - w - 8)
    y = T.clamp(y, 8, T.UI_H - h - 8)
    local g = love.graphics
    T.set({ 0.03, 0.05, 0.07 }, 0.97)
    rr("fill", x, y, w, h, 10)
    g.setLineWidth(2)
    T.set(C.rarityColor(d.rarity))
    rr("line", x, y, w, h, 10)
    T.textBox(d.name, x + 14, y + 8, w - 28, 25, T.fs(20), T.c.text, "left", "display")
    T.textBox(J.rarityName[d.rarity], x + 14, y + 34, w - 28, 18, T.fs(12), C.rarityColor(d.rarity), "left")
    T.text(text, x + 14, y + 58, T.fs(15), T.c.text, "left", w - 28)
    if extra then
        T.textBox(extra, x + 14, y + h - 32, w - 28, 24, T.fs(14), T.c.gold, "left")
    end
end

return C
