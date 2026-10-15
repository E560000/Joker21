local T = require("ui.theme")
local W = require("ui.widgets")
local C = require("ui.cardart")
local App = require("app")
local Save = require("game.save")

local Settings = {}

function Settings:enter()
    local o = T.opts
    local function set(key, v)
        o[key] = v
        Save.writeSettings(o)
    end
    local function percent(v) return math.floor(v * 100 + 0.5) .. "%" end
    local g = W.group()
    self.g = g
    local x, w = 344, 592
    local half = (w - 12) / 2
    g:add(W.segment { x = x, y = 172, w = w, h = 72, label = "SCORING ANIMATION SPEED",
        options = { "Normal", "Fast", "Instant" }, index = o.speed,
        onChange = function(i) set("speed", i) end })
    g:add(W.slider { x = x, y = 254, w = half, h = 60, label = "Music", min = 0, max = 1, step = 0.05,
        value = o.volume, fmt = percent, onChange = function(v) set("volume", v) end })
    g:add(W.slider { x = x + half + 12, y = 254, w = half, h = 60, label = "Sound effects", min = 0, max = 1,
        step = 0.05, value = o.sfx, fmt = percent, onChange = function(v) set("sfx", v) end })
    local toggles = {
        { "fourColor", "Four-colour deck", "Give every suit its own hue" },
        { "highContrast", "High contrast", "Black table, white lines and text" },
        { "reducedMotion", "Reduce motion", "Freeze the background, skip card flourishes" },
        { "largeText", "Large text", "Bigger labels throughout the interface" },
        { "showFps", "Show FPS", "Frame counter in the corner (F3)" },
    }
    for i, t in ipairs(toggles) do
        local key = t[1]
        g:add(W.toggle { x = x, y = 324 + (i - 1) * 58, w = w, h = 52, label = t[2], sub = t[3],
            value = o[key], onChange = function(v)
                set(key, v)
                if key == "highContrast" then T.refresh() end
            end })
    end
    g:add(W.button { x = 60, y = 640, w = 200, h = 54, label = "Back", icon = "back",
        onClick = function() App.go("menu") end })
    g:playIntro(0.04)
end

function Settings:update(dt) self.g:update(dt, App.mx, App.my) end

function Settings:draw()
    T.text("Settings", 60, 26, 44, T.c.text, "left", nil, "display")
    T.text("Make JOKER 21 comfortable to read and play.", 62, 84, T.fs(16), T.c.dim)
    W.panel(320, 130, 640, 494, "AUDIO, ACCESSIBILITY & DISPLAY")

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
