-- ui/sprite.lua
-- Tiny animation state for a card: smooth movement, flip, bump, hover lift.

local T = require("ui.theme")

local S = {}

function S.new(x, y)
    return { x = x, y = y, tx = x, ty = y, rot = 0, trot = 0, sc = 1, tsc = 1,
        flip = 1, tflip = 1, wait = 0, bump = 0, hover = 0, thover = 0, tilt = 0 }
end

function S.update(s, dt)
    if s.wait > 0 then
        s.wait = s.wait - dt
        return
    end
    local rm = T.opts.reducedMotion
    local k = rm and 1 or math.min(1, dt * 13)
    s.x = s.x + (s.tx - s.x) * k
    s.y = s.y + (s.ty - s.y) * k
    s.rot = s.rot + (s.trot - s.rot) * k
    s.sc = s.sc + (s.tsc - s.sc) * k
    s.flip = s.flip + (s.tflip - s.flip) * (rm and 1 or math.min(1, dt * 10))
    s.hover = s.hover + (s.thover - s.hover) * math.min(1, dt * 16)
    s.bump = math.max(0, s.bump - dt * 3.2)
end

function S.hit(s, mx, my, w, h)
    return mx >= s.x - w / 2 and mx <= s.x + w / 2 and my >= s.y - h / 2 and my <= s.y + h / 2
end

-- faceFn / backFn draw a card centred at the origin.
function S.draw(s, faceFn, backFn)
    if s.wait > 0 then return end
    local g = love.graphics
    g.push()
    g.translate(s.x, s.y - s.hover * 12)
    local wob = T.opts.reducedMotion and 0 or math.sin(s.bump * 22) * 0.07 * s.bump
    g.rotate(s.rot + s.tilt * s.hover + wob)
    local sx = math.abs(math.cos(math.pi * s.flip))
    local sc = s.sc * (1 + 0.16 * s.bump + 0.04 * s.hover)
    g.scale(math.max(0.02, sx) * sc, sc)
    if s.flip > 0.5 then faceFn() else backFn() end
    g.pop()
end

return S
