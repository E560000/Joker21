local T = require("ui.theme")
local W = require("ui.widgets")
local E = require("lib.easing")
local C = require("ui.cardart")
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
  T.text("Lead Development: E56", 62, 100, T.fs(20))
  T.text("Assisted Dev:          MeerkatOne", 62, 120, T.fs(20))
  T.text("Playtesters:", 62, 160, T.fs(20))
  T.text("TheBigCheezo", 268, 160, T.fs(20))
  T.text("Bigoodle", 268, 180, T.fs(20))
  T.text("Endzio", 268, 200, T.fs(20))
  T.text("Dellu", 268, 220, T.fs(20))
  T.text("Seppuku", 268, 240, T.fs(20))
  T.text("Tyler_WK", 268, 260, T.fs(20))
  T.text("Special Thanks:", 62, 300, T.fs(20))
  T.text("Thank YOU for playing!!", 62, 330, T.fs(20))
  self.g:draw()
end

function Credits:keypressed(k)
    if k == "escape" then App.go("settings") return end
    self.g:keypressed(k)
end
function Credits:mousepressed(x, y, b) self.g:mousepressed(x, y, b) end
function Credits:mousereleased() self.g:mousereleased() end

return Credits
