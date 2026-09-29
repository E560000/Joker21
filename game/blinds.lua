-- game/blinds.lua  -  blind targets and boss effects

local B = {}

B.ANTES = 8
-- Small-blind target per ante. Big = x1.5, Boss = x2 (before boss modifiers).
B.BASE = { 100, 250, 600, 1500, 4000, 10000, 22000, 50000 }

B.BOSSES = {
    { key = "sharp",  name = "The Sharp",  desc = "Dealer stands on 18 instead of 17", standAt = 18 },
    { key = "miser",  name = "The Miser",  desc = "Pushes count as losses",            pushLoses = true },
    { key = "plague", name = "The Plague", desc = "Face cards score 0 chips",          noFaceChips = true },
    { key = "wall",   name = "The Wall",   desc = "Target score is 50% larger",        tmult = 1.5 },
}

B.NAMES = { "Small Blind", "Big Blind", "Boss Blind" }
B.REWARD = { 3, 4, 5 }
B.SKIP_BONUS = 4

function B.make(ante, idx, boss)
    local base = B.BASE[math.min(ante, #B.BASE)]
    local mult = (idx == 1 and 1) or (idx == 2 and 1.5) or 2
    local b = { ante = ante, idx = idx, name = B.NAMES[idx], reward = B.REWARD[idx] }
    if idx == 3 and boss then
        b.boss = boss
        b.name = boss.name
        mult = mult * (boss.tmult or 1)
    end
    b.target = math.floor(base * mult + 0.5)
    return b
end

return B
