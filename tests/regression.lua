-- Run from the repository root with: lua tests/regression.lua
-- Exercise real game/screen modules without opening a window or touching saves.
local files, writes = {}, 0
local function noop() end
love = {
    filesystem = {
        write = function(path, contents) files[path] = contents; writes = writes + 1; return true end,
        read = function(path) return files[path] end,
        getInfo = function(path) return files[path] and { type = "file" } end,
        load = function(path)
            if loadstring then return assert(loadstring(files[path], "@" .. path)) end
            return assert(load(files[path], "@" .. path, "t", {}))
        end,
        remove = function(path) files[path] = nil; return true end,
    },
    keyboard = { isDown = function() return false end, setKeyRepeat = noop },
    mouse = { getPosition = function() return 0, 0 end },
    graphics = { getDimensions = function() return 1280, 720 end, setDefaultFilter = noop },
}

local Run = require("game.run")
local Round = require("game.round")
local Cards = require("game.cards")
local Score = require("game.score")
local Jokers = require("game.jokers")
local Blinds = require("game.blinds")
local Save = require("game.save")
local Table = require("screens.table")
local Menu = require("screens.menu")
local Shop = require("screens.shop")
local Over = require("screens.gameover")
local T = require("ui.theme")
local App = require("app")
local route, args, blocked
local function mockGo(name, _, data)
    if blocked then return false end
    route, args = name, data
    return true
end
App.go = mockGo

local passed = 0
local function test(name, fn)
    files, writes, Run.cur, route, args, blocked = {}, 0, nil, nil, nil, false
    Save.data = { bestAnte = 0, bestHand = 0, wins = 0, runs = 0 }
    T.opts.speed, T.opts.reducedMotion = 3, false
    App.go = mockGo
    math.randomseed(1234)
    fn()
    passed = passed + 1
    print("ok - " .. name)
end
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function fresh(...)
    local run = Run.new()
    for _, id in ipairs({...}) do run.jokers[#run.jokers + 1] = Jokers.new(id) end
    return run
end
local function take(round, rank, suit)
    suit = suit or "S"
    for i, card in ipairs(round.deck) do
        if card.rank == rank and card.suit == suit then return table.remove(round.deck, i) end
    end
    error("missing card " .. rank .. suit)
end
local function hand(round, player, dealer)
    round.deck, round.discard, round.player, round.dealer = Cards.newDeck(), {}, {}, {}
    for _, spec in ipairs(player) do round.player[#round.player + 1] = take(round, spec[1], spec[2]) end
    for _, spec in ipairs(dealer) do round.dealer[#round.dealer + 1] = take(round, spec[1], spec[2]) end
end
local function won(run)
    local round = Round.new(run, run:currentBlind())
    hand(round, {{"A"}, {"K"}}, {{"10", "H"}, {"8", "H"}})
    round:resolve()
    eq(round.result, "win")
    round:finishHand()
    -- Later antes need more than one natural to clear; this fixture represents
    -- the score accumulated before the final winning hand.
    round.score, round.phase = math.max(round.score, round.target), "won"
    return round
end
local function lost(run)
    local round = Round.new(run, run:currentBlind())
    round.handsLeft = 1
    hand(round, {{"10"}, {"7"}}, {{"K", "H"}, {"Q", "H"}})
    round:resolve()
    round:finishHand()
    eq(round.phase, "lost")
    return round
end
local function restart()
    Run.cur, route, args = nil, nil, nil
    Menu:enter()
    eq(Menu.g.items[1].label, "Continue")
    Menu.g.items[1].onClick()
    return Run.cur
end

test("Pity pays only the current hand and appears in the first loss banner", function()
    local run = fresh("pity")
    local round = Round.new(run, run:currentBlind())
    for i = 1, 2 do
        -- Use deal() between losses, including its per-hand reset.
        round.deck, round.discard = Cards.newDeck(), {}
        local sequence = {take(round, "10"), take(round, "K", "H"), take(round, "7"), take(round, "Q", "H")}
        for k = #sequence, 1, -1 do round.deck[#round.deck + 1] = sequence[k] end
        assert(round:deal())
        round:stand()
        round:dealerStep()
        eq(round.lossBonus, 5)
        run:save(round:saveState())
        run = restart()
        Table:enter()
        eq(Table.banner.sub, "Pity: +5 chips")
        round = Table.round
        round:finishHand()
        eq(round.score, 5 * i)
    end
end)

test("Vision and insurance retain use on resume and reset in the next blind", function()
    local run = fresh("vision", "insurance")
    local round = Round.new(run, run:currentBlind())
    assert(round:useDeckPeek())
    hand(round, {{"K"}, {"Q"}, {"2"}}, {{"10", "H"}, {"8", "H"}})
    round:resolve()
    assert(round.insured)
    run:save(round:saveState())
    run = restart()
    local restored = Round.restore(run, run:currentBlind(), run.savedRound)
    assert(not restored:deckPeekActive())
    assert(run.jokers[2].state.used)
    run:advance()
    local nextRound = Round.new(run, run:currentBlind())
    assert(nextRound:deckPeekActive())
    assert(not run.jokers[2].state.used)
end)

test("You Stupid counts every ten-value rank", function()
    local run = fresh("youstupid")
    local round = Round.new(run, run:currentBlind())
    for _, rank in ipairs({"10", "J", "Q", "K"}) do
        hand(round, {{"9"}, {rank}}, {{"10", "H"}, {"8", "H"}})
        eq(Score.handTotal(round), 21)
        round:resolve()
        eq(round.result, "win")
        eq(round.finalScore, 58)
    end
end)

test("Self-Employed negates every boss, including The Wall's displayed target", function()
    local run = fresh("selfemployed")
    run.blindIdx = 3
    for _, boss in ipairs(Blinds.BOSSES) do
        run.bosses[1] = boss
        local blind = run:currentBlind()
        eq(blind.target, 160)
        eq(run:blindList()[3].target, 160)
        assert(blind.bossDisabled)
        local round = Round.new(run, blind)
        assert(not round:bossActive())
        eq(round:standAt(), 17)
        hand(round, {{"K"}, {"7"}}, {{"10", "H"}, {"7", "H"}})
        round:resolve()
        eq(round.result, "push")
        eq(round.potentialScore, 27)
    end
    run:sell(run.jokers[1])
    eq(run:currentBlind().target, 240)
end)

test("a lost final sweep resumes game over in memory and after restart", function()
    local run = fresh()
    Table:enter()
    Table.round = lost(run)
    Table:saveProgress()
    Table.mode = "sweep"
    Table:setPaused(true)
    Table.pauseG.items[2].onClick()
    eq(route, "menu")
    Menu:enter()
    Menu.g.items[1].onClick()
    eq(route, "gameover")
    eq(args.victory, false)
    run = restart()
    eq(route, "gameover")
    eq(run.savedRound.handsLeft, 0)
    Over:enter(args)
    eq(Save.data.runs, 1)
    eq(Save.loadRun(), nil)
    eq(Run.cur, nil)
end)

test("an unpaid winning sweep resumes cashout and never deals a fresh blind", function()
    local run = fresh()
    local round = won(run)
    run:save(round:saveState())
    run = restart()
    eq(route, "table")
    local before = run.money
    Table:enter()
    eq(Table.mode, "cashout")
    eq(Table.round.score, round.score)
    eq(Table.round.handsLeft, 3)
    eq(run.money, before + Table.cashTotal)
    eq(run.stats.blinds, 1)
    Table:doDeal()
    eq(Table.round.phase, "won")
end)

test("cashout survives repeated restarts without repeating money or joker rewards", function()
    local run = fresh("ticket", "interest")
    local round = won(run)
    local _, total = run:cashOut(round)
    local money = run.money
    eq(total, 12)
    for _ = 1, 3 do
        run = restart()
        Table:enter()
        eq(Table.mode, "cashout")
        eq(Table.cashTotal, total)
        eq(run.money, money)
        eq(run.stats.blinds, 1)
    end
    local beforeWrites = writes
    Table:finishCash()
    eq(writes, beforeWrites + 1)
    eq(route, "shop")
    local saved = Save.loadRun()
    eq(saved.blindIdx, 2)
    eq(saved.screen, "shop")
    eq(saved.round, nil)
    eq(saved.cashout, nil)
    eq(#saved.shop.offers, 3)
    assert(not run:finishBlind())
    eq(run.blindIdx, 2)
    eq(run:cashOut(round), nil)
end)

test("shop offers, purchases, upgrades and reroll cost survive restart", function()
    local run = fresh()
    run.money = 100
    run:genShop()
    local id = run.shop.offers[1]
    assert(run:buyJoker(1))
    assert(run:buyUpgrade("hand"))
    assert(run:reroll())
    local offers, money = table.concat(run.shop.offers, ","), run.money
    run = restart()
    eq(route, "shop")
    eq(table.concat(run.shop.offers, ","), offers)
    eq(run.money, money)
    eq(run.shop.rerollCost, 3)
    eq(run.hands, 5)
    eq(run.jokers[1].id, id)
    Shop:enter()
    Shop.nextBtn.onClick()
    eq(route, "blinds")
    -- The shop remains the current screen during the first half of its fade.
    Shop:update(0.05)
    run = restart()
    eq(route, "blinds")
    eq(run.shop, nil)
end)

test("a stale round from another blind is discarded without changing run progress", function()
    for _, terminal in ipairs({false, true}) do
        local run = fresh()
        local round = terminal and won(run) or Round.new(run, run:currentBlind())
        local snapshot = round:saveState()
        run:advance()
        run:save(snapshot)
        run = restart()
        eq(route, "blinds")
        eq(run.blindIdx, 2)
        eq(run.savedRound, nil)
        Table:enter()
        eq(Table.round.phase, "idle")
        eq(Table.round.handsLeft, 4)
    end
end)

test("legacy snapshots and shops remain resumable", function()
    local run = fresh()
    local round = won(run)
    local snapshot = round:saveState()
    snapshot.ante, snapshot.blindIdx = nil, nil
    run:save(snapshot)
    local saved = Save.loadRun()
    saved.screen = nil
    Save.writeRun(saved)
    run = restart()
    Table:enter()
    eq(Table.mode, "cashout")
    run:finishBlind()
    saved = Save.loadRun()
    saved.screen = nil
    Save.writeRun(saved)
    restart()
    eq(route, "shop")
end)

test("idle saves with zero hands or enough score are routed to their terminal state", function()
    local run = fresh()
    local round = Round.new(run, run:currentBlind())
    round.handsLeft = 0
    run:save(round:saveState())
    restart()
    eq(route, "gameover")
    eq(args.victory, false)
    run = fresh()
    round = Round.new(run, run:currentBlind())
    round.score = round.target
    run:save(round:saveState())
    restart()
    Table:enter()
    eq(Table.mode, "cashout")
end)

test("a legacy Wall loss is cleared when Self-Employed removes the target penalty", function()
    local run = fresh("selfemployed")
    run.blindIdx = 3
    for _, boss in ipairs(Blinds.BOSSES) do
        if boss.key == "wall" then run.bosses[1] = boss end
    end
    local round = Round.new(run, run:currentBlind())
    round.score, round.handsLeft, round.phase = 200, 0, "lost"
    local snapshot = round:saveState()
    snapshot.ante, snapshot.blindIdx = nil, nil
    run:save(snapshot)
    run = restart()
    eq(route, "table")
    eq(run.savedRound.phase, "won")
    Table:enter()
    eq(Table.mode, "cashout")
    eq(Table.round.target, 160)
    eq(run.stats.blinds, 1)
end)

test("malformed saved runs cannot prevent the menu offering New Run", function()
    for _, saved in ipairs({{}, {ante = "bad", blindIdx = 1}, {ante = 1, blindIdx = 4},
        {ante = 1, blindIdx = 1, hands = 0}, {ante = 1, blindIdx = 1, jokers = "bad"},
        {ante = 1, blindIdx = 1, stats = {best = "bad"}}}) do
        Save.writeRun(saved)
        Run.cur = nil
        Menu:enter()
        eq(Run.cur, nil)
        eq(Menu.g.items[1].label, "New Run")
    end
end)

test("invalid round phases or missing cards fall back to a playable blind", function()
    for _, corrupt in ipairs({
        function(s) s.phase = "unknown" end,
        function(s) s.deck = {} end,
        function(s) s.player = false end,
        function(s) s.deck[1].rank = "invalid" end,
    }) do
        local run = fresh()
        local round = Round.new(run, run:currentBlind())
        local snapshot = round:saveState()
        corrupt(snapshot)
        run:save(snapshot)
        run = restart()
        eq(route, "blinds")
        Table:enter()
        Table:doDeal()
        assert(Table.mode ~= "idle")
    end
end)

test("final boss settlement resumes victory instead of a ninth ante", function()
    local run = fresh()
    run.ante, run.blindIdx = 8, 3
    run:rollBoss(8)
    run:cashOut(won(run))
    assert(run:finishBlind())
    eq(run.ante, 9)
    eq(run.shop, nil)
    restart()
    eq(route, "gameover")
    eq(args.victory, true)
end)

test("valid saved phases progress at all three animation speeds", function()
    for speed = 1, 3 do
        for _, phase in ipairs({"idle", "player", "dealer", "win", "lose", "bust", "push"}) do
            local run = fresh("insurance", "vision", "pity")
            local round = Round.new(run, run:currentBlind())
            T.opts.speed = speed
            if phase ~= "idle" then
                local p = phase == "win" and {{"A"}, {"K"}}
                    or phase == "bust" and {{"K"}, {"Q"}, {"2"}} or {{"10"}, {"7"}}
                hand(round, p, {{"10", "H"}, {phase == "push" and "7" or "8", "H"}})
                if phase == "player" or phase == "dealer" then round.phase = phase
                else round:resolve(); eq(round.result, phase) end
            end
            run:save(round:saveState())
            run = restart()
            Table:enter()
            route = nil
            for _ = 1, 3000 do
                if Table.mode == "idle" then Table:doDeal()
                elseif Table.mode == "player" then Table:doStand()
                elseif Table.mode == "cashout" then Table:finishCash() end
                Table:update(0.05)
                if route then break end
            end
            assert(route == "shop" or route == "gameover", phase .. " did not progress")
        end
    end
end)

test("restored loss retries game over after an incoming real screen transition", function()
    -- LÖVE has already required its runner's main module when these checks
    -- are launched inside the engine, so load the game's entry point directly.
    dofile("main.lua")
    -- main.lua installs the real transition function; unlike the mock, it
    -- rejects screen changes during a transition.
    local run = fresh()
    run:save(lost(run):saveState())
    love.load()
    assert(App.go("table", "iris"))
    assert(not App.go("menu"))
    for _ = 1, 30 do love.update(0.05) end
    eq(Over.run, run)
    eq(Run.cur, nil)
    eq(Save.data.runs, 1)
end)

print(passed .. " regression checks passed")
