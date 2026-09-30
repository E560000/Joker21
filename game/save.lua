local Save = { data = { bestAnte = 0, bestHand = 0, wins = 0, runs = 0 } }
local FILE = "stats.txt"

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

function Save.record(run, victory)
    local d = Save.data
    d.runs = d.runs + 1
    if victory then d.wins = d.wins + 1 end
    d.bestAnte = math.max(d.bestAnte, math.min(run.ante, 8))
    d.bestHand = math.max(d.bestHand, run.stats.best)
    Save.write()
end

return Save
