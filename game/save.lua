local Blinds = require("game.blinds")

local Save = { data = { bestAnte = 0, bestHand = 0, wins = 0, runs = 0 } }
local FILE = "stats.txt"
local RUN_FILE = "run.lua"

-- Save tables as Lua literals. The file is local game data and is loaded in an
-- empty environment so it cannot access Love or the host application.
local function literal(v)
    local kind = type(v)
    if kind == "nil" then return "nil" end
    if kind == "boolean" or kind == "number" then return tostring(v) end
    if kind == "string" then return string.format("%q", v) end
    if kind ~= "table" then return "nil" end
    local out = { "{" }
    for k, value in pairs(v) do
        out[#out + 1] = "[" .. literal(k) .. "]=" .. literal(value) .. ","
    end
    out[#out + 1] = "}"
    return table.concat(out)
end

function Save.writeRun(state)
    pcall(function()
        if love.filesystem and love.filesystem.write then
            love.filesystem.write(RUN_FILE, "return " .. literal(state))
        end
    end)
end

function Save.loadRun()
    if not (love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(RUN_FILE)) then return nil end
    local ok, chunk = pcall(love.filesystem.load, RUN_FILE)
    if not ok or not chunk then return nil end
    if setfenv then setfenv(chunk, {}) end
    local valid, state = pcall(chunk)
    if valid and type(state) == "table" then return state end
    return nil
end

function Save.clearRun()
    pcall(function()
        if love.filesystem and love.filesystem.remove then love.filesystem.remove(RUN_FILE) end
    end)
end

function Save.load()
    local ok = pcall(function()
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(FILE) then
            local text = love.filesystem.read(FILE)
            for k, v in tostring(text):gmatch("(%w+)=(%d+)") do
                if Save.data[k] ~= nil then Save.data[k] = tonumber(v) end
            end
        end
    end)
    return ok
end

function Save.write()
    pcall(function()
        if love.filesystem and love.filesystem.write then
            local out = {}
            for k, v in pairs(Save.data) do out[#out + 1] = k .. "=" .. math.floor(v) end
            love.filesystem.write(FILE, table.concat(out, "\n"))
        end
    end)
end

-- Settings are stored as key=value lines. Only known keys of the expected
-- type are applied, so an old or hand-edited file cannot break the options.
local SETTINGS_FILE = "settings.txt"
local SETTINGS = {
    highContrast = "boolean", reducedMotion = "boolean", largeText = "boolean",
    fourColor = "boolean", showFps = "boolean",
    speed = { 1, 3, 1 }, volume = { 0, 1 }, sfx = { 0, 1 },
}

function Save.loadSettings(opts)
    pcall(function()
        if not (love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(SETTINGS_FILE)) then return end
        local text = love.filesystem.read(SETTINGS_FILE)
        for k, v in tostring(text):gmatch("(%w+)=([%w%.]+)") do
            local kind = SETTINGS[k]
            if kind == "boolean" and (v == "true" or v == "false") then
                opts[k] = (v == "true")
            elseif type(kind) == "table" then
                local n = tonumber(v)
                if n and n == n and n >= kind[1] and n <= kind[2]
                    and (not kind[3] or n == math.floor(n)) then
                    opts[k] = n
                end
            end
        end
    end)
end

function Save.writeSettings(opts)
    pcall(function()
        if love.filesystem and love.filesystem.write then
            local out = {}
            for k in pairs(SETTINGS) do
                if opts[k] ~= nil then out[#out + 1] = k .. "=" .. tostring(opts[k]) end
            end
            table.sort(out)
            love.filesystem.write(SETTINGS_FILE, table.concat(out, "\n"))
        end
    end)
end

function Save.record(run, victory)
    local d = Save.data
    d.runs = d.runs + 1
    if victory then d.wins = d.wins + 1 end
    d.bestAnte = math.max(d.bestAnte, math.min(run.ante, Blinds.ANTES))
    d.bestHand = math.max(d.bestHand, run.stats.best)
    Save.write()
end

return Save
