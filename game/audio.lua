-- Optional game audio. Missing or unsupported files are skipped silently.

local T = require("ui.theme")

local Audio = {}
local music
local effects = {}
local extensions = { "ogg", "wav", "mp3" }
local files = {
    card_draw = "card_draw",
    loss = "loss",
    win = "win",
    points = "points",
    blind_select = "blind_select",
    joker_buy = "joker_buy",
    joker_sell = "joker_sell",
    score_end = "score_end",
    game_loss = "game_loss",
    click = "click",
    new_game = "new_game",
    music = "background_music",
}

local function loadSource(stem, kind)
    for _, ext in ipairs(extensions) do
        local path = "assets/audio/" .. stem .. "." .. ext
        if love.filesystem.getInfo(path) then
            local ok, source = pcall(love.audio.newSource, path, kind)
            if ok and source then return source end
        end
    end
end

function Audio.load()
    effects = {}
    for key, stem in pairs(files) do
        if key == "music" then
            music = loadSource(stem, "stream")
            if music then music:setLooping(true) end
        else
            local sample = loadSource(stem, "static")
            if sample then
                local voices = { sample }
                for _ = 1, 3 do
                    local ok, voice = pcall(sample.clone, sample)
                    if ok and voice then voices[#voices + 1] = voice end
                end
                effects[key] = { voices = voices, next = 1 }
            end
        end
    end
end

function Audio.startMusic()
    if not music then return end
    music:setVolume((T.opts.masterVolume or 1) * (T.opts.volume or 0.8))
    if not music:isPlaying() then music:play() end
end

function Audio.update()
    if music then music:setVolume((T.opts.masterVolume or 1) * (T.opts.volume or 0.8)) end
end

function Audio.play(name, pitch)
    local entry = effects[name]
    if not entry then return end
    local voice = entry.voices[entry.next]
    entry.next = entry.next % #entry.voices + 1
    voice:stop()
    voice:setVolume((T.opts.masterVolume or 1) * (T.opts.sfx or 0.8))
    voice:setPitch(T.clamp(pitch or 1, 0.5, 2.0))
    voice:play()
end

function Audio.stop(name)
    local entry = effects[name]
    if not entry then return end
    for _, voice in ipairs(entry.voices) do voice:stop() end
end

return Audio
