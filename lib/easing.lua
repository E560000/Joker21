-- lib/easing.lua
-- A tiny set of easing functions. Each takes t in [0,1] and returns
-- an eased progress value (also roughly in [0,1]) used to drive
-- position, scale and color interpolation throughout the demo.

local easing = {}

function easing.linear(t)
    return t
end

function easing.quadInOut(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return 1 - ((-2 * t + 2) ^ 2) / 2
    end
end

function easing.cubicOut(t)
    local f = t - 1
    return f * f * f + 1
end

function easing.backOut(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local f = t - 1
    return 1 + c3 * f * f * f + c1 * f * f
end

function easing.elasticOut(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local c4 = (2 * math.pi) / 3
    return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
end

function easing.bounceOut(t)
    local n1, d1 = 7.5625, 2.75
    if t < 1 / d1 then
        return n1 * t * t
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + 0.9375
    else
        t = t - 2.625 / d1
        return n1 * t * t + 0.984375
    end
end

function easing.sineInOut(t)
    return -(math.cos(math.pi * t) - 1) / 2
end

return easing
