local T = require("ui.theme")
local W = require("ui.widgets")
local C = require("ui.cardart")
local App = require("app")

local Settings = {}

function Settings:enter()
    local o = T.opts
    local g = W.group()
    self.g = g
    local x, w = 344, 592
    g:add(W.segment { x = x, y = 176, w = w, h = 76, label = "SCORING ANIMATION SPEED",
        options = { "Normal", "Fast", "Instant" }, index = o.speed,
        onChange = function(i) o.speed = i end })
    g:add(W.toggle { x = x, y = 262, w = w, h = 60, label = "Four-colour deck",
        sub = "Give every suit its own hue", value = o.fourColor,
        onChange = function(v) o.fourColor = v end })
    g:add(W.toggle { x = x, y = 330, w = w, h = 60, label = "High contrast",
        sub = "Black table, white lines and text", value = o.highContrast,
        onChange = function(v) o.highContrast = v; T.refresh() end })
    g:add(W.toggle { x = x, y = 398, w = w, h = 60, label = "Reduce motion",
        sub = "Freeze the background, skip card flourishes", value = o.reducedMotion,
        onChange = function(v) o.reducedMotion = v end })
    g:add(W.toggle { x = x, y = 466, w = w, h = 60, label = "Large text",
        sub = "Bigger labels throughout the interface", value = o.largeText,
        onChange = function(v) o.largeText = v end })
    g:add(W.toggle { x = x, y = 534, w = w, h = 60, label = "Show FPS",
        sub = "Frame counter in the corner (F3)", value = o.showFps,
        onChange = function(v) o.showFps = v end })
    g:add(W.button { x = 60, y = 640, w = 200, h = 54, label = "Back", icon = "back",
        onClick = function() App.go("menu") end })
    g:add(W.button { x = 300, y = 640, w = 200, h = 54, label = "Credits", icon = "flag",
        onClick = function() App.go("credits") end})
    g:playIntro(0.04)
end

function Settings:update(dt) self.g:update(dt, App.mx, App.my) end

function Settings:draw()
    T.text("Settings", 60, 26, 44, T.c.text, "left", nil, "display")
    T.text("Make JOKER 21 comfortable to read and play.", 62, 84, T.fs(16), T.c.dim)
    W.panel(320, 130, 640, 484, "ACCESSIBILITY & DISPLAY")

    -- live suit-colour preview
    for i, s in ipairs({ "S", "H", "D", "C" }) do
        local cx = 852 + (i - 1) * 24
        C.suit(s, cx, 146, 8, { 0.97, 0.95, 0.90 })
        C.suit(s, cx, 146, 6, T.suitColor(s))
    end
    self.g:draw()
end

function Settings:keypressed(k)
    if k == "escape" then App.go("menu") return end
    self.g:keypressed(k)
end
function Settings:mousepressed(x, y, b) self.g:mousepressed(x, y, b) end
function Settings:mousereleased() self.g:mousereleased() end

return Settings
