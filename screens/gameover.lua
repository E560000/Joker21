-- screens/gameover.lua  -  defeat / victory summary

local T = require("ui.theme")
local W = require("ui.widgets")
local E = require("lib.easing")
local C = require("ui.cardart")
local Run = require("game.run")
local Save = require("game.save")
local App = require("app")
local Audio = require("game.audio")

local Over = {}

function Over:enter(args)
    args = args or {}
    self.victory = args.victory and true or false
    if not self.victory then Audio.play("game_loss") end
    self.run = Run.cur or Run.new()
    self.t = 0
    Save.record(self.run, self.victory)
    Run.cur = nil
    local g = W.group()
    self.g = g
    g:add(W.button { x = 420, y = 610, w = 220, h = 56, label = "New Run", icon = "restart", primary = true,
        onClick = function() Run.new(); Audio.play("new_game"); App.go("blinds", "iris") end })
    g:add(W.button { x = 660, y = 610, w = 220, h = 56, label = "Main Menu", icon = "back",
        onClick = function() App.go("menu") end })
    g.focus = 1
    g:playIntro(0.1)
end

function Over:update(dt)
    self.t = self.t + dt
    self.g:update(dt, App.mx, App.my)
end

function Over:draw()
    local run, g = self.run, love.graphics
    local e = E.backOut(T.clamp(self.t / 0.6, 0, 1))
    if T.opts.reducedMotion then e = 1 end
    g.push()
    g.translate(T.W / 2, 92)
    g.scale(e, e)
    love.graphics.setFont(T.font("display", 76))
    T.set({ 0, 0, 0 }, 0.5)
    g.printf(self.victory and "VICTORY!" or "GAME OVER", -400 + 4, -40 + 5, 800, "center")
    T.set(self.victory and T.c.gold or T.c.bad)
    g.printf(self.victory and "VICTORY!" or "GAME OVER", -400, -40, 800, "center")
    g.pop()
    T.text(self.victory and "You beat all 8 antes. The house is broke." or
        "The dealer takes this one.", 0, 146, T.fs(18), T.c.dim, "center", T.W)

    W.panel(340, 190, 600, 250)
    local st = run.stats
    local rows = {
        { "ANTE REACHED", tostring(math.min(run.ante, 8)) },
        { "BLINDS CLEARED", tostring(st.blinds) },
        { "HANDS PLAYED", tostring(st.hands) },
        { "HANDS WON", tostring(st.wins) },
        { "BEST HAND", T.commas(st.best) },
        { "MONEY", "$" .. run.money },
    }
    for i, r in ipairs(rows) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = 372 + col * 290, 214 + row * 70
        T.spaced(r[1], x, y, T.fs(12), T.c.dim, 3)
        T.text(r[2], x, y + 20, T.fs(30), T.c.text, "left", nil, "display")
    end

    W.panel(340, 452, 600, 140, "YOUR JOKERS")
    if #run.jokers == 0 then
        T.text("None.", 372, 510, T.fs(18), T.c.dim)
    end
    for i, j in ipairs(run.jokers) do
        g.push()
        g.translate(392 + (i - 1) * 78, 534)
        g.scale(0.62, 0.62)
        C.joker(j.def)
        g.pop()
    end
    self.g:draw()
end

function Over:keypressed(k) self.g:keypressed(k) end
function Over:mousepressed(x, y, b) self.g:mousepressed(x, y, b) end
function Over:mousereleased() self.g:mousereleased() end

return Over
