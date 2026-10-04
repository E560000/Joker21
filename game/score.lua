local Cards = require("game.cards")

local S = {}
S.BASE_CHIPS = 10
S.BASE_MULT = 1

function S.handTotal(round, hand)
    hand = hand or round.player
    local total = Cards.total(hand)
    if total > 21 then return total end
    for _, j in ipairs(round.run.jokers) do
        if j.def.special21 then
            local hasNine, hasTen = false, false
            for _, card in ipairs(hand) do
                if card.rank == "9" then hasNine = true end
                if card.rank == "10" or Cards.isFace(card) then hasTen = true end
            end
            if hasNine and hasTen then return 21 end
        end
    end
    return total
end

function S.compute(round)
    local run = round.run
    local hand = round.player
    local total = S.handTotal(round, hand)
    local ctx = {
        hand = hand, dealer = round.dealer, total = total,
        natural = Cards.isNatural(hand),
        dealerBust = Cards.total(round.dealer) > 21,
        doubled = round.doubled, result = round.result, nCards = #hand,
    }
    local boss = round:bossActive() and round.blind.boss
    local chips, mult = S.BASE_CHIPS, S.BASE_MULT
    local steps = {}

    local function push(s)
        if s.chips then chips = chips + s.chips end
        if s.mult then mult = mult + s.mult end
        if s.xmult then mult = mult * s.xmult end
        s.cAfter, s.mAfter = chips, mult
        steps[#steps + 1] = s
    end

    for i, card in ipairs(hand) do
        local cc = Cards.chips(card)
        if boss and boss.noFaceChips and Cards.isFace(card) then cc = 0 end
        push { kind = "card", cardIndex = i, chips = cc }
        for _, j in ipairs(run.jokers) do
            if j.def.onCard then
                local r = j.def.onCard(ctx, card, j)
                if r then push { kind = "joker", joker = j, cardIndex = i,
                    chips = r.chips, mult = r.mult, xmult = r.xmult } end
            end
        end
    end

    if ctx.natural then
        push { kind = "bonus", label = "Blackjack!", mult = 3 }
    elseif total == 21 then
        push { kind = "bonus", label = "Twenty-One", mult = 1 }
    end
    if ctx.dealerBust then
        push { kind = "bonus", label = "Dealer Bust", mult = 1 }
    end

    for _, j in ipairs(run.jokers) do
        if j.def.onHand then
            local r = j.def.onHand(ctx, j)
            if r then push { kind = "joker", joker = j,
                chips = r.chips, mult = r.mult, xmult = r.xmult } end
        end
    end

    if round.doubled then
        push { kind = "double", label = "Double Down", xmult = 2 }
    end

    return { steps = steps, score = math.floor(chips * mult + 0.0001),
        chips = chips, mult = mult, ctx = ctx }
end

return S
