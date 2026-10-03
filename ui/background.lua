local T = require("ui.theme")
local C = require("ui.cardart")

local BG = { t = 0, parts = {} }

local SRC = [[
uniform float uTime;
uniform vec2 uRes;
uniform vec3 c1;
uniform vec3 c2;
uniform vec3 c3;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 p = (sc / uRes) * 2.0 - 1.0;
    p.x *= uRes.x / uRes.y;
    float len = length(p);
    float ang = atan(p.y, p.x) + len * 3.2 - uTime * 0.16;
    float w = sin(ang * 3.0 + uTime * 0.32) * 0.5 + 0.5;
    float w2 = sin(len * 7.0 - uTime * 0.44 + ang) * 0.5 + 0.5;
    vec3 col = mix(c1, c2, w * 0.75);
    col = mix(col, c3, w2 * 0.22);
    col *= 1.0 - 0.32 * len * len * 0.5;
    return vec4(col, 1.0) * color;
}
]]

function BG.init()
    local suits = { "S", "H", "D", "C" }
    for i = 1, 16 do
        local x = math.random() * T.UI_W
        BG.parts[i] = { x = x, baseX = x, y = math.random() * T.UI_H,
            vy = 8 + math.random() * 12, r = 16 + math.random() * 26,
            suit = suits[math.random(1, 4)], a = 0.04 + math.random() * 0.05,
            spin = (math.random() - 0.5) * 0.5, rot = math.random() * 6.28,
            phase = math.random() * 6.28 }
    end
    if love.graphics.newShader then
        local ok, sh = pcall(love.graphics.newShader, SRC)
        BG.shader = ok and sh or nil
    end
end

function BG.update(dt)
    if T.opts.reducedMotion then return end
    BG.t = BG.t + dt
    for _, p in ipairs(BG.parts) do
        p.y = p.y - p.vy * dt
        p.rot = p.rot + p.spin * dt
        p.x = p.baseX + math.sin(BG.t * 0.45 + p.phase) * 18
        if p.y < -40 then
            p.y, p.baseX = T.UI_H + 40, math.random() * T.UI_W
        end
    end
end

local function send(sh, name, ...)
    if sh:hasUniform(name) then pcall(sh.send, sh, name, ...) end
end

function BG.draw(tint)
    local g = love.graphics
    if T.opts.highContrast then
        g.clear(0, 0, 0, 1)
        return
    end
    local c = T.c
    local k = tint or { 1, 1, 1 }
    local c1 = { c.felt1[1] * k[1], c.felt1[2] * k[2], c.felt1[3] * k[3] }
    local c2 = { c.felt2[1] * k[1], c.felt2[2] * k[2], c.felt2[3] * k[3] }
    local c3 = { c.felt3[1] * k[1], c.felt3[2] * k[2], c.felt3[3] * k[3] }
    if BG.shader then
        local w, h = g.getDimensions()
        g.setShader(BG.shader)
        send(BG.shader, "uTime", BG.t)
        send(BG.shader, "uRes", { w, h })
        send(BG.shader, "c1", c1)
        send(BG.shader, "c2", c2)
        send(BG.shader, "c3", c3)
        g.setColor(1, 1, 1, 1)
        g.rectangle("fill", 0, 0, T.UI_W, T.UI_H)
        g.setShader()
    else
        g.setColor(c1)
        g.rectangle("fill", 0, 0, T.UI_W, T.UI_H)
        for i = 6, 1, -1 do
            g.setColor(c2[1], c2[2], c2[3], 0.16)
            g.circle("fill", T.UI_W / 2, T.UI_H / 2, 110 * i)
        end
    end
    for _, p in ipairs(BG.parts) do
        g.push()
        g.translate(p.x, p.y)
        g.rotate(p.rot)
        C.suit(p.suit, 0, 0, p.r, { 1, 1, 1 }, p.a)
        g.pop()
    end
end

return BG
