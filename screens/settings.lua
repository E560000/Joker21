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
    g:add(W.segment { x = x, y = 168, w = w, h = 68, label = "SCORING ANIMATION SPEED",
        options = { "Normal", "Fast", "Instant" }, index = o.speed,
        onChange = function(i) o.speed = i end })
    g:add(W.slider { x = x, y = 244, w = w, h = 54, label = "Master volume",
        min = 0, max = 100, step = 1, value = math.floor((o.masterVolume or 1) * 100 + 0.5),
        fmt = function(v) return string.format("%d%%", v) end,
        onChange = function(v) o.masterVolume = v / 100; T.saveOptions() end })
    g:add(W.slider { x = x, y = 306, w = w, h = 54, label = "Effects volume",
        min = 0, max = 100, step = 1, value = math.floor((o.sfx or 0.8) * 100 + 0.5),
        fmt = function(v) return string.format("%d%%", v) end,
        onChange = function(v) o.sfx = v / 100; T.saveOptions() end })
    g:add(W.slider { x = x, y = 368, w = w, h = 54, label = "Music volume",
        min = 0, max = 100, step = 1, value = math.floor((o.volume or 0.8) * 100 + 0.5),
        fmt = function(v) return string.format("%d%%", v) end,
        onChange = function(v) o.volume = v / 100; T.saveOptions() end })
    g:add(W.toggle { x = x, y = 430, w = w, h = 44, label = "Four-colour deck",
        sub = "Give every suit its own hue", value = o.fourColor,
        onChange = function(v) o.fourColor = v; T.saveOptions() end })
    g:add(W.toggle { x = x, y = 478, w = w, h = 44, label = "High contrast",
        sub = "Black table, white lines and text", value = o.highContrast,
        onChange = function(v) o.highContrast = v; T.refresh(); T.saveOptions() end })
    g:add(W.toggle { x = x, y = 526, w = w, h = 44, label = "Reduce motion",
        sub = "Freeze the background, skip card flourishes", value = o.reducedMotion,
        onChange = function(v) o.reducedMotion = v; T.saveOptions() end })
    g:add(W.toggle { x = x, y = 574, w = w, h = 44, label = "Large text",
        sub = "Bigger labels throughout the interface", value = o.largeText,
        onChange = function(v) o.largeText = v; T.saveOptions() end })
    g:add(W.toggle { x = x, y = 622, w = w, h = 44, label = "Show FPS",
        sub = "Frame counter in the corner (F3)", value = o.showFps,
        onChange = function(v) o.showFps = v; T.saveOptions() end })
    g:add(W.button { x = 60, y = 654, w = 200, h = 54, label = "Back", icon = "back",
        onClick = function() App.go("menu") end })
    g:add(W.button { x = 1030, y = 654, w = 200, h = 54, label = "Credits", icon = "flag",
        onClick = function() App.go("credits") end})
    g:playIntro(0.04)
end

function Settings:update(dt) self.g:update(dt, App.mx, App.my) end

function Settings:draw()
    T.text("Settings", 60, 26, 44, T.c.text, "left", nil, "display")
    W.panel(320, 100, 640, 600, "AUDIO, ACCESSIBILITY & DISPLAY")

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
