-- ui/theme.lua
-- Design tokens + small drawing helpers shared by every screen.
-- (Reused from the Sector2D UI kit; retuned for a card-table look.)

local T = {}

-- The game renders into a 2K virtual canvas. UI layout values remain in the
-- original 1280x720 design units and are scaled up by the main draw transform.
T.W, T.H = 2560, 1440
T.UI_W, T.UI_H = 1280, 720
T.alpha = 1 -- global alpha multiplier (used by intros / fades)

-- Use Neonderthaw for the game wordmark and Julius Sans One for all other
-- interface and card text.
T.fontFiles = {
    display = "fonts/JuliusSansOne-Regular.ttf",
    body = "fonts/JuliusSansOne-Regular.ttf",
    title = "fonts/Neonderthaw-Regular.ttf",
}

T.opts = {
    highContrast = false,
    reducedMotion = false,
    largeText = false,
    fourColor = false,   -- four-colour deck (distinct hue per suit)
    speed = 1,           -- scoring animation speed: 1 normal, 2 fast, 3 instant
    showFps = false,
    masterVolume = 1,
    volume = 0.8,
    sfx = 0.8,
    palette = "classic", -- kept for the shared segment widget
}

local optionsFile = "options.lua"
local optionKeys = { "highContrast", "reducedMotion", "largeText", "fourColor",
    "speed", "showFps", "masterVolume", "volume", "sfx" }

local function serializeOptions(value)
    local fields = {}
    for key, item in pairs(value) do
        local encoded = type(item) == "string" and string.format("%q", item) or tostring(item)
        fields[#fields + 1] = "[" .. string.format("%q", key) .. "]=" .. encoded
    end
    return "{" .. table.concat(fields, ",") .. "}"
end

function T.loadOptions()
    if not (love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(optionsFile)) then return end
    local ok, chunk = pcall(love.filesystem.load, optionsFile)
    if not ok or not chunk then return end
    if setfenv then setfenv(chunk, {}) end
    local valid, saved = pcall(chunk)
    if not valid or type(saved) ~= "table" then return end
    for _, key in ipairs(optionKeys) do
        if type(saved[key]) == type(T.opts[key]) then T.opts[key] = saved[key] end
    end
    for _, key in ipairs({ "masterVolume", "volume", "sfx" }) do
        T.opts[key] = T.clamp(T.opts[key], 0, 1)
    end
end

function T.saveOptions()
    pcall(function()
        local saved = {}
        for _, key in ipairs(optionKeys) do saved[key] = T.opts[key] end
        love.filesystem.write(optionsFile, "return " .. serializeOptions(saved))
    end)
end

T.dirs = { "up", "right", "down", "left" }
T.angle = { up = -math.pi / 2, right = 0, down = math.pi / 2, left = math.pi }
T.vec = { up = { 0, -1 }, right = { 1, 0 }, down = { 0, 1 }, left = { -1, 0 } }

T.c = {}
function T.refresh()
    local hc = T.opts.highContrast
    local c = T.c
    c.bg      = hc and { 0, 0, 0 }             or { 0.030, 0.120, 0.100 }
    c.panel   = hc and { 0.03, 0.03, 0.03 }    or { 0.070, 0.105, 0.120 }
    c.panel2  = hc and { 0.10, 0.10, 0.10 }    or { 0.125, 0.170, 0.195 }
    c.line    = hc and { 1, 1, 1 }             or { 0.290, 0.380, 0.420 }
    c.text    = hc and { 1, 1, 1 }             or { 0.960, 0.960, 0.940 }
    c.dim     = hc and { 0.86, 0.86, 0.86 }    or { 0.620, 0.700, 0.720 }
    c.accent  = hc and { 1.00, 1.00, 0.00 }    or { 1.000, 0.580, 0.160 }
    c.accent2 = hc and { 1.00, 0.60, 0.00 }    or { 1.000, 0.820, 0.300 }
    c.ok      = { 0.40, 0.95, 0.55 }
    c.bad     = { 1.00, 0.35, 0.38 }
    c.dark    = { 0.020, 0.040, 0.050 }
    c.chips   = { 0.25, 0.58, 1.00 }
    c.mult    = { 1.00, 0.30, 0.32 }
    c.gold    = { 1.00, 0.82, 0.30 }
    c.felt1   = { 0.330, 0.140, 0.410 }
    c.felt2   = { 0.250, 0.050, 0.390 }
    c.felt3   = { 0.100, 0.040, 0.270 }
end
T.refresh()

-- Suit ink colour on a card face.
local suitInk = {
    classic = { S = { 0.38, 0.00, 0.42 }, C = { 0.38, 0.00, 0.42 },
                H = { 0.16, 0.64, 0.20 }, D = { 0.16, 0.64, 0.20 } },
    four    = { S = { 0.08, 0.08, 0.12 }, C = { 0.10, 0.52, 0.24 },
                H = { 0.86, 0.14, 0.20 }, D = { 0.14, 0.38, 0.88 } },
}
function T.suitColor(suit)
    return (T.opts.fourColor and suitInk.four or suitInk.classic)[suit]
end

-- ---------------------------------------------------------------- utils

function T.lerp(a, b, t) return a + (b - a) * t end

function T.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function T.mix(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

function T.set(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (a or 1) * (c[4] or 1) * T.alpha)
end

function T.lane(dir) return T.palettes[T.opts.palette][dir] end

function T.fs(n) return math.floor(n * (T.opts.largeText and 1.18 or 1) + 0.5) end

function T.commas(n)
    local s = tostring(math.floor(n))
    local k
    repeat
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until k == 0
    return s
end

function T.fmtTime(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function T.rrect(mode, x, y, w, h, r)
    love.graphics.rectangle(mode, x, y, w, h, r, r)
end

-- ---------------------------------------------------------------- text

local fontCache = {}
function T.font(role, size)
    size = math.floor(size + 0.5)
    local key = role .. ":" .. size
    if not fontCache[key] then
        local f
        local path = T.fontFiles[role]
        if path and love.filesystem.getInfo(path) then
            local ok, res = pcall(love.graphics.newFont, path, size * 2)
            if ok then f = res end
        end
        f = f or love.graphics.newFont(size * 2)
        f:setFilter("linear", "linear", 1)
        fontCache[key] = {
            native = f,
            getWidth = function(_, str) return f:getWidth(str) / 2 end,
            getHeight = function() return f:getHeight() / 2 end,
            getWrap = function(_, str, width)
                local wrappedWidth, lines = f:getWrap(str, width * 2)
                return wrappedWidth / 2, lines
            end,
        }
    end
    return fontCache[key]
end

-- Fonts are rasterized at 2x, then drawn at half scale inside the 2x canvas
-- transform. This preserves layout while keeping glyph edges crisp at 2K.
function T.setFont(font)
    love.graphics.setFont(font.native)
end

function T.print(str, x, y)
    local g = love.graphics
    g.push()
    g.translate(x, y)
    g.scale(0.5, 0.5)
    g.print(str, 0, 0)
    g.pop()
end

function T.printf(str, x, y, width, align)
    local g = love.graphics
    g.push()
    g.translate(x, y)
    g.scale(0.5, 0.5)
    g.printf(str, 0, 0, width * 2, align)
    g.pop()
end

-- Left/right/centre text. Pass w for printf-style alignment.
function T.text(str, x, y, size, color, align, w, role)
    str = tostring(str or "")
    local fontSize = size
    -- Unbounded single-line labels still belong to the visible canvas. Scale
    -- them down to the remaining width instead of letting them clip offscreen.
    if not w and not str:find("\n", 1, true) then
        local available = math.max(1, T.UI_W - x)
        while fontSize > 7 and T.font(role or "body", fontSize):getWidth(str) > available do
            fontSize = fontSize - 1
        end
    end
    T.setFont(T.font(role or "body", fontSize))
    T.set(color or T.c.text)
    if w then
        T.printf(str, x, y, w, align or "left")
    else
        T.print(str, x, y)
    end
end

-- Text vertically centred inside a box.
function T.textBox(str, x, y, w, h, size, color, align, role, alpha)
    str = tostring(str or "")
    local fontSize = size
    local f = T.font(role or "body", fontSize)
    local _, lines = f:getWrap(str, math.max(1, w))
    while fontSize > 7 and (#lines * f:getHeight() > h or f:getWidth(str) > w and #lines <= 1) do
        fontSize = fontSize - 1
        f = T.font(role or "body", fontSize)
        _, lines = f:getWrap(str, math.max(1, w))
    end
    T.setFont(f)
    T.set(color or T.c.text, alpha)
    local textHeight = #lines * f:getHeight()
    T.printf(str, x, y + math.max(0, (h - textHeight) / 2), w, align or "center")
end

-- Letter-spaced small caps style text.
function T.spaced(str, x, y, size, color, spacing, role)
    local f = T.font(role or "body", size)
    T.setFont(f)
    T.set(color or T.c.dim)
    local cx = x
    for ch in str:gmatch(".") do
        T.print(ch, cx, y)
        cx = cx + f:getWidth(ch) + spacing
    end
    return cx - x
end

-- ---------------------------------------------------------------- shapes

function T.glyph(dir, cx, cy, s, color, alpha)
    local g = love.graphics
    g.push()
    g.translate(cx, cy)
    g.rotate(T.angle[dir])
    T.set(color, alpha)
    g.polygon("fill", s, 0, -s * 0.8, -s * 0.9, -s * 0.8, s * 0.9)
    g.pop()
end

function T.glow(x, y, r, color, alpha)
    for i = 1, 6 do
        T.set(color, (alpha or 0.3) / (i + 1))
        love.graphics.circle("fill", x, y, r * (0.6 + i * 0.28))
    end
end

local dirNames = { up = true, right = true, down = true, left = true }

-- Draws a keycap; returns its width. Direction names draw an arrow glyph.
function T.keycap(label, x, y, size)
    size = size or 26
    local g = love.graphics
    local isDir = dirNames[label]
    local f, w
    if isDir then
        w = size
    else
        f = T.font("body", size * 0.55)
        w = math.max(size, f:getWidth(label) + 16)
    end
    T.set(T.c.panel2)
    T.rrect("fill", x, y, w, size, 6)
    g.setLineWidth(1.5)
    T.set(T.c.line)
    T.rrect("line", x, y, w, size, 6)
    if isDir then
        T.glyph(label, x + w / 2, y + size / 2, size * 0.26, T.c.text)
    else
        T.setFont(f)
        T.set(T.c.text)
        T.printf(label, x, y + (size - f:getHeight()) / 2, w, "center")
    end
    return w
end

function T.icon(name, cx, cy, s, color, alpha)
    local g = love.graphics
    T.set(color or T.c.text, alpha)
    g.setLineWidth(math.max(2, s * 0.22))
    if name == "play" then
        g.polygon("fill", cx - s * 0.6, cy - s, cx - s * 0.6, cy + s, cx + s, cy)
    elseif name == "pause" then
        g.rectangle("fill", cx - s * 0.75, cy - s * 0.9, s * 0.55, s * 1.8)
        g.rectangle("fill", cx + s * 0.2, cy - s * 0.9, s * 0.55, s * 1.8)
    elseif name == "back" then
        g.line(cx + s * 0.5, cy - s, cx - s * 0.6, cy, cx + s * 0.5, cy + s)
    elseif name == "quit" then
        g.line(cx - s * 0.8, cy - s * 0.8, cx + s * 0.8, cy + s * 0.8)
        g.line(cx + s * 0.8, cy - s * 0.8, cx - s * 0.8, cy + s * 0.8)
    elseif name == "gear" then
        g.circle("line", cx, cy, s * 0.55)
        for i = 0, 7 do
            local a = i * math.pi / 4
            g.line(cx + math.cos(a) * s * 0.78, cy + math.sin(a) * s * 0.78,
                   cx + math.cos(a) * s * 1.0, cy + math.sin(a) * s * 1.0)
        end
    elseif name == "edit" then
        g.line(cx - s * 0.8, cy + s * 0.8, cx + s * 0.7, cy - s * 0.7)
        g.polygon("fill", cx - s, cy + s, cx - s * 0.9, cy + s * 0.35, cx - s * 0.35, cy + s * 0.9)
    elseif name == "save" then
        g.rectangle("line", cx - s * 0.9, cy - s * 0.9, s * 1.8, s * 1.8, 3, 3)
        g.rectangle("fill", cx - s * 0.5, cy - s * 0.9, s, s * 0.6)
        g.rectangle("line", cx - s * 0.5, cy + s * 0.1, s, s * 0.8)
    elseif name == "plus" then
        g.line(cx - s * 0.8, cy, cx + s * 0.8, cy)
        g.line(cx, cy - s * 0.8, cx, cy + s * 0.8)
    elseif name == "trash" then
        g.line(cx - s * 0.9, cy - s * 0.6, cx + s * 0.9, cy - s * 0.6)
        g.rectangle("line", cx - s * 0.6, cy - s * 0.6, s * 1.2, s * 1.5)
        g.line(cx - s * 0.3, cy - s * 0.95, cx + s * 0.3, cy - s * 0.95)
    elseif name == "prev" then
        g.polygon("fill", cx + s * 0.8, cy - s * 0.9, cx + s * 0.8, cy + s * 0.9, cx - s * 0.5, cy)
        g.rectangle("fill", cx - s * 0.95, cy - s * 0.9, s * 0.28, s * 1.8)
    elseif name == "next" then
        g.polygon("fill", cx - s * 0.8, cy - s * 0.9, cx - s * 0.8, cy + s * 0.9, cx + s * 0.5, cy)
        g.rectangle("fill", cx + s * 0.67, cy - s * 0.9, s * 0.28, s * 1.8)
    elseif name == "restart" then
        g.arc("line", "open", cx, cy, s * 0.75, -math.pi * 0.15, math.pi * 1.45, 24)
        g.polygon("fill", cx + s * 0.35, cy - s * 1.05, cx + s * 1.05, cy - s * 0.55, cx + s * 0.25, cy - s * 0.2)
    elseif name == "flag" then
        g.line(cx - s * 0.7, cy - s, cx - s * 0.7, cy + s)
        g.polygon("fill", cx - s * 0.7, cy - s, cx + s * 0.9, cy - s * 0.5, cx - s * 0.7, cy)
    end
end

return T
