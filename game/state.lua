-- Small validators for local saved data.
local State = {}

function State.number(v, minimum)
    return type(v) == "number" and v == v and v < math.huge and v >= (minimum or 0)
end

function State.integer(v, minimum, maximum)
    return State.number(v, minimum) and v == math.floor(v) and (not maximum or v <= maximum)
end

function State.array(v, check, maximum)
    if type(v) ~= "table" then return false end
    local n = #v
    if maximum and n > maximum then return false end
    for k, value in pairs(v) do
        if not State.integer(k, 1, n) or not check(value) then return false end
    end
    for i = 1, n do if v[i] == nil then return false end end
    return true
end

return State
