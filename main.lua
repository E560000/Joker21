local T = require("ui.theme")
local BG = require("ui.background")
local App = require("app")
local Save = require("game.save")
local Audio = require("game.audio")

local screens = {}
local current
local scale, ox, oy = 1, 0, 0
local trans = { active = false }

local function layout()
    local ww, wh = love.graphics.getDimensions()
    scale = math.min(ww / T.W, wh / T.H)
    ox, oy = (ww - T.W * scale) / 2, (wh - T.H * scale) / 2
end

local function toVirtual(x, y)
    return (x - ox) / (scale * 2), (y - oy) / (scale * 2)
end

local function switchTo(name, args)
    current = screens[name]
    if current.enter then current:enter(args) end
end

-- kind: "fade" | "iris"
function App.go(name, kind, args)
    if trans.active then return false end
    local reduced = T.opts.reducedMotion
    trans = {
        active = true, timer = 0, swapped = false,
        dur = reduced and 0.25 or 0.6,
        kind = reduced and "fade" or (kind or "fade"),
        name = name, args = args,
    }
    return true
end

function love.load()
    -- The 2K virtual canvas is scaled to the window; use smooth texture and
    -- font filtering so the enlarged UI does not look blocky.
    love.graphics.setDefaultFilter("linear", "linear", 1)
    math.randomseed(os.time())
    love.keyboard.setKeyRepeat(true)
    T.refresh()
    Audio.load()
    Audio.startMusic()
    BG.init()
    Save.load()
    screens.menu = require("screens.menu")
    screens.howto = require("screens.howto")
    screens.settings = require("screens.settings")
    screens.credits = require("screens.credits")
    screens.blinds = require("screens.blinds")
    screens.table = require("screens.table")
    screens.shop = require("screens.shop")
    screens.gameover = require("screens.gameover")
    switchTo("menu")
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    layout()
    App.mx, App.my = toVirtual(love.mouse.getPosition())
    Audio.update()
    BG.update(dt)

    if trans.active then
        trans.timer = trans.timer + dt
        local t = math.min(trans.timer / trans.dur, 1)
        if t >= 0.5 and not trans.swapped then
            trans.swapped = true
            switchTo(trans.name, trans.args)
        end
        if trans.kind == "iris" then
            local maxR = math.sqrt(T.UI_W ^ 2 + T.UI_H ^ 2) / 2
            trans.radius = (t < 0.5) and maxR * (1 - t / 0.5) or maxR * ((t - 0.5) / 0.5)
        else
            trans.alpha = (t < 0.5) and (t / 0.5) or (1 - (t - 0.5) / 0.5)
        end
        if t >= 1 then trans.active = false end
    end
    if current.update then current:update(dt) end
end

function love.draw()
    local g = love.graphics
    g.clear(T.c.bg[1], T.c.bg[2], T.c.bg[3], 1)
    g.setScissor(ox, oy, T.W * scale, T.H * scale)
    g.push()
    g.translate(ox, oy)
    g.scale(scale * 2, scale * 2)

    BG.draw(current.tint)
    current:draw()

    if trans.active then
        if trans.kind == "iris" then
            g.stencil(function() g.circle("fill", T.UI_W / 2, T.UI_H / 2, trans.radius) end, "replace", 1)
            g.setStencilTest("equal", 0)
            g.setColor(0.01, 0.05, 0.04, 1)
            g.rectangle("fill", 0, 0, T.UI_W, T.UI_H)
            g.setStencilTest()
        else
            g.setColor(0.01, 0.05, 0.04, trans.alpha)
            g.rectangle("fill", 0, 0, T.UI_W, T.UI_H)
        end
    end

    if T.opts.showFps then
        T.text(love.timer.getFPS() .. " fps", T.UI_W - 90, T.UI_H - 24, 14, T.c.dim)
    end
    g.pop()
    g.setScissor()
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
        return
    elseif key == "f3" then
        T.opts.showFps = not T.opts.showFps
        return
    end
    if trans.active then return end
    if current.keypressed then current:keypressed(key, isrepeat) end
end

function love.mousepressed(x, y, button)
    if trans.active then return end
    local vx, vy = toVirtual(x, y)
    if current.mousepressed then current:mousepressed(vx, vy, button) end
end

function love.mousereleased(x, y, button)
    local vx, vy = toVirtual(x, y)
    if current.mousereleased then current:mousereleased(vx, vy, button) end
end
