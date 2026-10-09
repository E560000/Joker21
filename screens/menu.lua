local T = require("ui.theme")
local W = require("ui.widgets")
local C = require("ui.cardart")
local Sprite = require("ui.sprite")
local Save = require("game.save")
local Run = require("game.run")
local Jokers = require("game.jokers")
local App = require("app")
local Audio = require("game.audio")

local Menu = {}

local FAN = {
    { kind = "card", rank = "A", suit = "S" },
    { kind = "card", rank = "K", suit = "H" },
    { kind = "joker", id = "momentum" },
    { kind = "card", rank = "10", suit = "D" },
    { kind = "card", rank = "J", suit = "C" },
}

function Menu:enter()
    if not Run.cur then
        local saved = Save.loadRun()
        if saved then Run.restore(saved) end
    end
    self.t = 0
    self.sprites = {}
    for i, f in ipairs(FAN) do
        local s = Sprite.new(900, 900)
        local k = i - 3
        s.tx = 930 + k * 92
        s.ty = 370 + math.abs(k) * 22
        s.trot = k * 0.17
        s.wait = 0.08 * i
        s.flip = 0
        s.tflip = 1
        s.baseY = s.ty
        self.sprites[i] = s
    end

    local g = W.group()
    self.g = g
    local x, w, h, gap, y = 90, 380, 60, 12, 290
    local hasRun = Run.cur ~= nil and not Run.cur.over
    local items = {}
    if hasRun then
        items[#items + 1] = { "Continue", "play", true, "Ante " .. Run.cur.ante .. " - $" .. Run.cur.money,
            function()
                local screen, args = Run.cur:resumeScreen()
                App.go(screen, "iris", args)
            end }
    end
    items[#items + 1] = { "New Run", "restart", not hasRun, "Beat 8 antes to win",
        function() Run.new(); Audio.play("new_game"); App.go("blinds", "iris") end }
    items[#items + 1] = { "How to Play", "flag", false, "Rules and scoring",
        function() App.go("howto") end }
    items[#items + 1] = { "Settings", "gear", false, "Accessibility and display",
        function() App.go("settings") end }
    items[#items + 1] = { "Quit", "quit", false, nil, function() love.event.quit() end }
    for i, it in ipairs(items) do
        g:add(W.button { x = x, y = y + (i - 1) * (h + gap), w = w, h = h, label = it[1],
            icon = it[2], primary = it[3], sub = it[4], danger = (it[1] == "Quit"),
            onClick = it[5] })
    end
    g.focus = 1
    g:playIntro(0.07)
end

function Menu:update(dt)
    self.t = self.t + dt
    self.g:update(dt, App.mx, App.my)
    for i, s in ipairs(self.sprites) do
        local hov = Sprite.hit(s, App.mx, App.my, C.CW, C.CH)
        s.thover = hov and 1 or 0
        s.tilt = T.clamp((App.mx - s.x) / 60, -1, 1) * 0.1
        if not T.opts.reducedMotion then
            s.ty = s.baseY + math.sin(self.t * 1.4 + i) * 5
        end
        Sprite.update(s, dt)
    end
end

function Menu:draw()
    local g = love.graphics
    local pulse = T.opts.reducedMotion and 0 or (math.sin(self.t * 2) * 0.5 + 0.5)

    local big = T.font("title", 108)
    T.setFont(big)
    T.set({ 0, 0, 0 }, 0.35)
    T.print("JOKER", 94, 104)
    T.set(T.c.text)
    T.print("JOKER", 90, 98)
    local sw = big:getWidth("JOKER")
    T.set({ 0, 0, 0 }, 0.35)
    T.print("21", 90 + sw + 20, 104)
    T.set(T.mix(T.c.accent, T.c.gold, pulse))
    T.print("21", 86 + sw + 20, 98)
    T.set(T.c.text)
    T.spaced("STEM EDITION", 94, 254, T.fs(13), T.c.dim, 3)
    -- card fan
    for i, s in ipairs(self.sprites) do
        local f = FAN[i]
        Sprite.draw(s, function()
            if f.kind == "card" then C.face(f, C.CW, C.CH)
            else C.joker(Jokers.byId[f.id], C.CW * 0.9, C.CH * 0.9) end
        end, function() C.back(C.CW, C.CH) end)
    end

    self.g:draw()

    -- stats
    local d = Save.data
    W.panel(745, 510, 380, 76)
    T.spaced("BEST ANTE", 765, 524, T.fs(11), T.c.dim, 3)
    T.text(tostring(d.bestAnte), 795, 540, T.fs(28), T.c.gold, "left", nil, "display")
    T.spaced("BEST HAND", 880, 524, T.fs(11), T.c.dim, 3)
    T.text(T.commas(d.bestHand), 895, 540, T.fs(28), T.c.text, "left", nil, "display")
    T.spaced("RUNS / WINS", 1005, 524, T.fs(11), T.c.dim, 3)
    T.text(d.runs .. " / " .. d.wins, 1020, 540, T.fs(28), T.c.text, "left", nil, "display")

    local fx = 160
    fx = fx + T.keycap("up", fx, 684, 24) + 4
    fx = fx + T.keycap("down", fx, 684, 24) + 6
    T.text("Navigate", fx, 687, T.fs(13), T.c.dim)
    fx = fx + 74
    fx = fx + T.keycap("Enter", fx, 684, 24) + 6
    T.text("Select", fx, 687, T.fs(13), T.c.dim)
end

function Menu:keypressed(k) self.g:keypressed(k) end
function Menu:mousepressed(x, y, b) self.g:mousepressed(x, y, b) end
function Menu:mousereleased() self.g:mousereleased() end

return Menu
