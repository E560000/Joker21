-- game/cards.lua  -  deck, chip values, blackjack totals

local Cards = {}

Cards.RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
Cards.SUITS = { "S", "H", "D", "C" }
Cards.SUIT_NAMES = { S = "Spades", H = "Hearts", D = "Diamonds", C = "Clubs" }

function Cards.isFace(c)
    return c.rank == "J" or c.rank == "Q" or c.rank == "K"
end

-- Chips a card is worth when scored (Ace = 11).
function Cards.chips(c)
    if c.rank == "A" then return 11 end
    if Cards.isFace(c) then return 10 end
    return tonumber(c.rank)
end

-- Blackjack total. Returns total, isSoft.
function Cards.total(hand)
    local t, aces = 0, 0
    for _, c in ipairs(hand) do
        if c.rank == "A" then aces = aces + 1 end
        t = t + Cards.chips(c)
    end
    while t > 21 and aces > 0 do
        t = t - 10
        aces = aces - 1
    end
    return t, aces > 0
end

function Cards.isNatural(hand)
    return #hand == 2 and Cards.total(hand) == 21
end

function Cards.newDeck()
    local d = {}
    for _, s in ipairs(Cards.SUITS) do
        for _, r in ipairs(Cards.RANKS) do
            d[#d + 1] = { rank = r, suit = s }
        end
    end
    return d
end

function Cards.shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

function Cards.name(c)
    return c.rank .. c.suit
end

return Cards
