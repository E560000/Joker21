local T = require("ui.theme")
local W = require("ui.widgets")
local App = require("app")

local Credits = {}

function Credits:enter()
    local g = W.group()
    self.g = g
    g:add(W.button { x = 60, y = 640, w = 200, h = 54, label = "Back", icon = "back",
        onClick = function() App.go("settings") end })
end
function Credits:update(dt) self.g:update(dt, App.mx, App.my) end

function Credits:draw()
    T.text("Credits", 60, 26, 44, T.c.text, "left", nil, "display")
    W.panel(320, 100, 640, 520, "Internal ")

    T.text("LEAD DEVELOPMENT", 356, 148, T.fs(14), T.c.dim)
    T.text("E56", 356, 170, T.fs(20), T.c.text)
    T.text("ASSISTED DEVELOPMENT", 356, 207, T.fs(14), T.c.dim)
    T.text("MeerkatOne", 356, 229, T.fs(20), T.c.text)

    T.text("PLAYTESTERS", 356, 266, T.fs(14), T.c.dim)
    T.text("TheBigCheezo   ·   Bigoodle   ·   Endzio", 356, 288, T.fs(18), T.c.text)
    T.text("Dellu   ·   Seppuku   ·   Tyler_WK   ·   .i_am_alex", 356, 314, T.fs(18), T.c.text)

    T.text("ORIGINAL SOUNDTRACK", 356, 360, T.fs(14), T.c.dim)
    T.text("TheBigCheezo", 356, 382, T.fs(20), T.c.text)
    
    T.text("INSPIRATION", 356, 420, T.fs(14), T.c.dim)
    T.text("LocalThunk - Balatro", 356, 440, T.fs(20), T.c.text)

    T.set(T.c.line, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.line(356, 496, 924, 496)
    T.text("Special thanks to everyone who helped make this game.", 356, 525, T.fs(17), T.c.dim)
    T.text("Thank you for playing!", 356, 562, T.fs(24), T.c.accent)

    self.g:draw()
end

function Credits:keypressed(k)
    if k == "escape" then App.go("settings") return end
    self.g:keypressed(k)
end
function Credits:mousepressed(x, y, b) self.g:mousepressed(x, y, b) end
function Credits:mousereleased() self.g:mousereleased() end

return Credits
