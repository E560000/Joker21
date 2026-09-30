local T = require("ui.theme")
local E = require("lib.easing")
local Audio = require("game.audio")

local W = {}

local function approach(cur, target, dt, speed)
    return cur + (target - cur) * math.min(1, dt * speed)
end

local function inside(it, x, y)
    return x >= it.x and x <= it.x + it.w and y >= it.y and y <= it.y + it.h
end

-- ------------------------------------------------------------- creation

local function init(kind, p)
    p.kind = kind
    p.hover, p.press, p.focusAnim = 0, 0, 0
    p.intro = 1
    p.enabled = (p.enabled ~= false)
    return p
end

function W.button(p)
    local it = init("button", p)
    it.onClick = it.onClick or function() end
    return it
end

function W.toggle(p)
    local it = init("toggle", p)
    it.value = p.value and true or false
    it.anim = it.value and 1 or 0
    function it:toggle()
        self.value = not self.value
        if self.onChange then self.onChange(self.value) end
    end
    return it
end

function W.slider(p)
    local it = init("slider", p)
    it.min, it.max = p.min or 0, p.max or 1
    it.value = p.value or it.min
    it.fmt = p.fmt or function(v) return tostring(v) end
    local function set(self, v)
        v = T.clamp(v, self.min, self.max)
        if self.step then v = math.floor(v / self.step + 0.5) * self.step end
        v = T.clamp(v, self.min, self.max)
        if v ~= self.value then
            self.value = v
            if self.onChange then self.onChange(v) end
        end
    end
    function it:setFromX(mx)
        local x0, x1 = self.x + 18, self.x + self.w - 18
        set(self, self.min + T.clamp((mx - x0) / (x1 - x0), 0, 1) * (self.max - self.min))
    end
    function it:nudge(d)
        set(self, self.value + d * (self.step or (self.max - self.min) / 20))
    end
    return it
end

function W.segment(p)
    local it = init("segment", p)
    it.index = p.index or 1
    it.hoverIndex = 0
    local function set(self, i)
        i = T.clamp(i, 1, #self.options)
        if i ~= self.index then
            self.index = i
            if self.onChange then self.onChange(i, self.options[i]) end
        end
    end
    function it:segRect(i)
        local sx, sw = self.x + 14, self.w - 28
        local cw = sw / #self.options
        return sx + (i - 1) * cw, self.y + 32, cw, self.h - 44
    end
    function it:pickAt(mx)
        local sx, sw = self.x + 14, self.w - 28
        local i = math.floor((mx - sx) / (sw / #self.options)) + 1
        set(self, i)
    end
    function it:shift(d) set(self, self.index + d) end
    function it:setIndex(i) self.index = T.clamp(i, 1, #self.options) end
    return it
end

-- ------------------------------------------------------------- group

local Group = {}
Group.__index = Group

function W.group()
    return setmetatable({ items = {}, focus = 0, dragging = nil,
        lastMx = -1, lastMy = -1, focusByMouse = false }, Group)
end

function Group:add(it)
    it.group = self
    self.items[#self.items + 1] = it
    return it
end

function Group:playIntro(step)
    for i, it in ipairs(self.items) do
        it.introT = -(i - 1) * step
        it.intro = 0
    end
end

function Group:update(dt, mx, my)
    local moved = (mx ~= self.lastMx or my ~= self.lastMy)
    self.lastMx, self.lastMy = mx, my
    local over
    for i, it in ipairs(self.items) do
        local isOver = it.enabled and not it.hidden and inside(it, mx, my)
        if isOver then over = i end
        it.hover = approach(it.hover, isOver and 1 or 0, dt, 14)
        it.press = approach(it.press, it.pressed and 1 or 0, dt, 22)
        it.focusAnim = approach(it.focusAnim, (self.focus == i) and 1 or 0, dt, 14)
        if it.kind == "toggle" then
            it.anim = T.opts.reducedMotion and (it.value and 1 or 0)
                or approach(it.anim, it.value and 1 or 0, dt, 14)
        end
        if it.kind == "segment" then
            it.hoverIndex = 0
            if isOver and my >= it.y + 32 then
                local sx, sw = it.x + 14, it.w - 28
                local i2 = math.floor((mx - sx) / (sw / #it.options)) + 1
                if i2 >= 1 and i2 <= #it.options then it.hoverIndex = i2 end
            end
        end
        if it.introT then
            it.introT = it.introT + dt
            local t = T.clamp(it.introT / 0.5, 0, 1)
            if T.opts.reducedMotion then t = (it.introT >= 0) and 1 or 0 end
            it.intro = E.cubicOut(t)
            if t >= 1 then it.introT = nil end
        end
    end
    if moved then
        if over then
            self.focus, self.focusByMouse = over, true
        elseif self.focusByMouse then
            self.focus = 0
        end
    end
    if self.dragging then self.dragging:setFromX(mx) end
end

function Group:mousepressed(x, y, b)
    if b ~= 1 then return false end
    for i, it in ipairs(self.items) do
        if it.enabled and not it.hidden and inside(it, x, y) then
            self.focus, self.focusByMouse = i, true
            Audio.play("click")
            if it.kind == "slider" then
                self.dragging = it
                it:setFromX(x)
            elseif it.kind == "segment" then
                if y >= it.y + 32 then it:pickAt(x) end
            elseif it.kind == "toggle" then
                it:toggle()
            else
                it.pressed = true
                it.onClick(it)
            end
            return true
        end
    end
    return false
end

function Group:mousereleased()
    self.dragging = nil
    for _, it in ipairs(self.items) do it.pressed = false end
end

function Group:keypressed(k)
    local n = #self.items
    local function step(dir)
        local i = self.focus
        if i == 0 and dir < 0 then i = n + 1 end
        for _ = 1, n do
            i = i + dir
            if i > n then i = 1 elseif i < 1 then i = n end
            if self.items[i].enabled and not self.items[i].hidden then
                self.focus, self.focusByMouse = i, false
                return
            end
        end
    end
    local shift = love.keyboard.isDown("lshift", "rshift")
    if k == "down" or (k == "tab" and not shift) then
        step(1)
        return true
    elseif k == "up" or (k == "tab" and shift) then
        step(-1)
        return true
    end
    local it = self.items[self.focus]
    if not it or it.hidden or not it.enabled then return false end
    if k == "left" or k == "right" then
        local d = (k == "left") and -1 or 1
        if it.kind == "slider" then it:nudge(d) return true end
        if it.kind == "segment" then it:shift(d) return true end
        return false
    elseif k == "return" or k == "kpenter" or k == "space" then
        Audio.play("click")
        if it.kind == "toggle" then
            it:toggle()
        elseif it.kind == "button" then
            it.press = 1
            it.onClick(it)
        elseif it.kind == "segment" then
            if it.index >= #it.options then it:setIndex(1) else it:shift(1) end
            if it.onChange then it.onChange(it.index, it.options[it.index]) end
        end
        return true
    end
    return false
end

-- ------------------------------------------------------------- drawing

local function rowBase(it, focused)
    local g = love.graphics
    T.set(T.mix(T.c.panel, T.c.panel2, it.hover * 0.9 + it.focusAnim * 0.5))
    T.rrect("fill", it.x, it.y, it.w, it.h, 10)
    g.setLineWidth(focused and 2.5 or 1.5)
    T.set(focused and T.c.accent or T.c.line)
    T.rrect("line", it.x, it.y, it.w, it.h, 10)
end

local drawers = {}

function drawers.button(it, focused)
    local g = love.graphics
    local x, y, w, h = it.x, it.y + it.press * 2, it.w, it.h
    local base = it.primary and T.mix(T.c.panel2, T.c.accent, 0.22) or T.c.panel
    T.set(T.mix(base, T.c.accent, it.hover * 0.14 + it.focusAnim * 0.06))
    T.rrect("fill", x, y, w, h, 10)
    -- accent bar on the left grows on hover / focus
    local barCol = it.danger and T.c.bad or T.c.accent
    T.set(barCol, 0.55 + 0.45 * math.max(it.hover, it.focusAnim))
    g.rectangle("fill", x + 1, y + 10, 4 + 6 * math.max(it.hover, it.focusAnim), h - 20, 2, 2)
    g.setLineWidth(focused and 2.5 or 1.5)
    T.set(focused and (it.danger and T.c.bad or T.c.accent) or T.c.line)
    T.rrect("line", x, y, w, h, 10)

    local size = T.fs(it.size or 22)
    local tx = x + 24
    if it.icon then
        T.icon(it.icon, x + 38, y + h / 2, it.iconSize or 11,
            it.danger and T.c.bad or (it.primary and T.c.accent or T.c.text))
        tx = x + 70
    end
    if it.sub then
        local textW = math.max(1, w - (tx - x) - 14)
        T.textBox(it.label, tx, y + 4, textW, h * 0.54, size, T.c.text, "left")
        T.textBox(it.sub, tx, y + h * 0.53, textW, h * 0.40, T.fs(14), T.c.dim, "left")
    elseif it.icon then
        T.textBox(it.label, tx, y, w - (tx - x) - 12, h, size, T.c.text, "left")
    else
        T.textBox(it.label, x, y, w, h, size, T.c.text, "center")
    end
    if it.hint then
        T.textBox(it.hint, x, y, w - 18, h, T.fs(14), T.c.dim, "right")
    end
end

function drawers.toggle(it, focused)
    local g = love.graphics
    rowBase(it, focused)
    local size = T.fs(20)
    if it.sub then
        T.text(it.label, it.x + 18, it.y + it.h / 2 - size * 0.95, size, T.c.text)
        T.text(it.sub, it.x + 18, it.y + it.h / 2 + size * 0.1, T.fs(13), T.c.dim)
    else
        T.textBox(it.label, it.x + 18, it.y, it.w - 130, it.h, size, T.c.text, "left")
    end
    local tw, th = 52, 28
    local tx, ty = it.x + it.w - tw - 18, it.y + it.h / 2 - th / 2
    T.set(T.mix(T.c.line, T.c.accent, it.anim))
    T.rrect("fill", tx, ty, tw, th, th / 2)
    T.set(T.c.dark)
    T.rrect("fill", tx + 3, ty + 3, tw - 6, th - 6, (th - 6) / 2)
    T.set(T.mix(T.c.line, T.c.accent, it.anim), 0.35 + 0.65 * it.anim)
    T.rrect("fill", tx + 3, ty + 3, tw - 6, th - 6, (th - 6) / 2)
    T.set(T.c.text)
    g.circle("fill", tx + 14 + it.anim * 24, ty + th / 2, 9)
    T.textBox(it.value and "On" or "Off", tx - 56, it.y, 46, it.h, T.fs(15),
        it.value and T.c.accent or T.c.dim, "right")
end

function drawers.slider(it, focused)
    local g = love.graphics
    rowBase(it, focused)
    T.text(it.label, it.x + 18, it.y + 10, T.fs(18), T.c.text)
    T.text(it.fmt(it.value), it.x + 18, it.y + 10, T.fs(18), T.c.accent, "right", it.w - 36)
    local x0, x1 = it.x + 18, it.x + it.w - 18
    local ty = it.y + it.h - 20
    T.set(T.c.dark)
    T.rrect("fill", x0, ty - 3, x1 - x0, 6, 3)
    local f = (it.value - it.min) / (it.max - it.min)
    T.set(T.c.accent)
    T.rrect("fill", x0, ty - 3, math.max(6, (x1 - x0) * f), 6, 3)
    local r = 8 + 3 * math.max(it.hover, it.focusAnim)
    T.set(T.c.text)
    g.circle("fill", x0 + (x1 - x0) * f, ty, r)
end

function drawers.segment(it, focused)
    local g = love.graphics
    rowBase(it, focused)
    T.text(it.label, it.x + 16, it.y + 9, T.fs(15), T.c.dim)
    for i, opt in ipairs(it.options) do
        local sx, sy, sw, sh = it.segRect(it, i)
        local sel = (i == it.index)
        local hov = (i == it.hoverIndex)
        T.set(sel and T.mix(T.c.panel2, T.c.accent, 0.28) or T.mix(T.c.dark, T.c.panel2, hov and 1 or 0.6))
        T.rrect("fill", sx + 2, sy, sw - 4, sh, 7)
        g.setLineWidth(sel and 2.5 or 1.2)
        T.set(sel and T.c.accent or T.c.line, sel and 1 or 0.8)
        T.rrect("line", sx + 2, sy, sw - 4, sh, 7)
        if it.icons then
            T.glyph(it.icons[i], sx + sw / 2, sy + sh / 2, 8, T.lane(it.icons[i]), sel and 1 or 0.65)
        else
            T.textBox(opt, sx, sy, sw, sh, T.fs(it.textSize or 16), sel and T.c.text or T.c.dim, "center")
        end
    end
end

function Group:draw()
    for i, it in ipairs(self.items) do
        if not it.hidden then
            local prev = T.alpha
            T.alpha = prev * it.intro * (it.enabled and 1 or 0.38)
            love.graphics.push()
            if not T.opts.reducedMotion then
                love.graphics.translate(-40 * (1 - it.intro), 0)
            end
            drawers[it.kind](it, self.focus == i and it.enabled)
            love.graphics.pop()
            T.alpha = prev
        end
    end
end

-- ------------------------------------------------------------- panels

-- Rounded panel with an optional letter-spaced title.
function W.panel(x, y, w, h, title)
    local g = love.graphics
    T.set(T.c.panel, 0.92)
    T.rrect("fill", x, y, w, h, 14)
    g.setLineWidth(1.5)
    T.set(T.c.line)
    T.rrect("line", x, y, w, h, 14)
    if title then
        T.set(T.c.accent)
        g.rectangle("fill", x + 18, y + 20, 4, 14, 2, 2)
        T.spaced(title, x + 30, y + 17, T.fs(14), T.c.dim, 3)
    end
end

-- Small rounded label.
function W.chip(str, x, y, color, size)
    size = T.fs(size or 14)
    local f = T.font("body", size)
    local w = f:getWidth(str) + 22
    local h = size + 12
    T.set(color or T.c.accent, 0.16)
    T.rrect("fill", x, y, w, h, h / 2)
    love.graphics.setLineWidth(1.5)
    T.set(color or T.c.accent)
    T.rrect("line", x, y, w, h, h / 2)
    T.textBox(str, x, y, w, h, size, color or T.c.accent, "center")
    return w, h
end

return W
