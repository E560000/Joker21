-- game/jokers.lua  -  joker definitions
--
-- Hooks (all optional):
--   onCard(ctx, card, inst)  -> {chips=, mult=, xmult=}   per scored card
--   onHand(ctx, inst)        -> {chips=, mult=, xmult=}   once per winning hand
--   onHandEnd(ctx, inst)     state bookkeeping after every hand
--   onBlindEnd(run, inst)    -> dollars earned when a blind is cleared
-- Flags: insurance (first bust each blind is free), peek (see hole card).
-- ctx = { hand, dealer, total, natural, dealerBust, doubled, result, nCards }

local Cards = require("game.cards")

local J = {}

local function isRed(card) return card.suit == "H" or card.suit == "D" end

J.list = {
    { id = "jester", name = "Jester", rarity = 1, cost = 3, art = "J",
      desc = "+2 Mult",
      onHand = function() return { mult = 2 } end },

    { id = "lucky7", name = "Lucky Seven", rarity = 1, cost = 4, art = "7",
      desc = "Each 7 scored: +4 Mult",
      onCard = function(ctx, card)
          if card.rank == "7" then return { mult = 4 } end
      end },

    { id = "facefan", name = "Face Fan", rarity = 1, cost = 4, art = "K",
      desc = "Each face card scored: +3 Mult",
      onCard = function(ctx, card)
          if Cards.isFace(card) then return { mult = 3 } end
      end },

    { id = "acehigh", name = "Ace High", rarity = 1, cost = 4, art = "A",
      desc = "Each Ace scored: +4 Mult",
      onCard = function(ctx, card)
          if card.rank == "A" then return { mult = 4 } end
      end },

    { id = "heart", name = "Heart Throb", rarity = 1, cost = 4, art = "H", suit = "H",
      desc = "Each Heart scored: +3 Mult",
      onCard = function(ctx, card)
          if card.suit == "H" then return { mult = 3 } end
      end },

    { id = "spade", name = "Spade Digger", rarity = 1, cost = 4, art = "S", suit = "S",
      desc = "Each Spade scored: +25 Chips",
      onCard = function(ctx, card)
          if card.suit == "S" then return { chips = 25 } end
      end },

    { id = "spender", name = "Big Spender", rarity = 1, cost = 4, art = "$",
      desc = "+50 Chips",
      onHand = function() return { chips = 50 } end },

    { id = "standfirm", name = "Stand Firm", rarity = 1, cost = 5, art = "17",
      desc = "Hand total 17-20: +5 Mult",
      onHand = function(ctx)
          if ctx.total >= 17 and ctx.total <= 20 then return { mult = 5 } end
      end },

    { id = "deepdraw", name = "Deep Draw", rarity = 1, cost = 5, art = "+",
      desc = "+3 Mult per card beyond your first two",
      onHand = function(ctx)
          if ctx.nCards > 2 then return { mult = 3 * (ctx.nCards - 2) } end
      end },

    { id = "reds", name = "Red Baron", rarity = 1, cost = 4, art = "R", suit = "D",
      desc = "Each red card scored: +15 Chips",
      onCard = function(ctx, card)
          if isRed(card) then return { chips = 15 } end
      end },

    { id = "bane", name = "Dealer's Bane", rarity = 2, cost = 6, art = "!",
      desc = "Dealer busts: +8 Mult",
      onHand = function(ctx)
          if ctx.dealerBust then return { mult = 8 } end
      end },

    { id = "streak", name = "Hot Streak", rarity = 2, cost = 6, art = "^",
      desc = function(inst)
          local n = inst.state.streak or 0
          return "+2 Mult per win in a row (now +" .. (2 * n) .. ")"
      end,
      onHand = function(ctx, inst)
          local n = inst.state.streak or 0
          if n > 0 then return { mult = 2 * n } end
      end,
      onHandEnd = function(ctx, inst)
          if ctx.result == "win" then
              inst.state.streak = (inst.state.streak or 0) + 1
          elseif ctx.result == "lose" or ctx.result == "bust" then
              inst.state.streak = 0
          end
      end },

    { id = "insurance", name = "Insurance Agent", rarity = 2, cost = 6, art = "i",
      desc = "First bust each blind doesn't use a hand",
      insurance = true },

    { id = "counter", name = "Card Counter", rarity = 2, cost = 5, art = "#",
      desc = "See the dealer's hole card",
      peek = true },

    { id = "ticket", name = "Golden Ticket", rarity = 2, cost = 5, art = "T",
      desc = "Earn $4 more when a blind is cleared",
      onBlindEnd = function() return 4 end },

    { id = "gambler", name = "Gambler's Fallacy", rarity = 2, cost = 6, art = "?",
      desc = function(inst)
          return "After a loss, your next win gets +12 Mult" ..
              (inst.state.charged and " (charged!)" or "")
      end,
      onHand = function(ctx, inst)
          if inst.state.charged then return { mult = 12 } end
      end,
      onHandEnd = function(ctx, inst)
          if ctx.result == "lose" or ctx.result == "bust" then
              inst.state.charged = true
          elseif ctx.result == "win" then
              inst.state.charged = false
          end
      end },

    { id = "interest", name = "Compound Interest", rarity = 2, cost = 7, art = "%",
      desc = "Earn $1 per $4 you hold at blind end (max $6)",
      onBlindEnd = function(run)
          return math.min(6, math.floor(run.money / 4))
      end },

    { id = "snowball", name = "Snowball", rarity = 2, cost = 6, art = "*",
      desc = function(inst)
          return "Gains +1 Mult for every hand you win (now +" .. (inst.state.bonus or 0) .. ")"
      end,
      onHand = function(ctx, inst)
          local n = inst.state.bonus or 0
          if n > 0 then return { mult = n } end
      end,
      onHandEnd = function(ctx, inst)
          if ctx.result == "win" then inst.state.bonus = (inst.state.bonus or 0) + 1 end
      end },

    { id = "pity", name = "Pity", rarity = 2, cost = 6, art = "%",
      desc = "On a loss, gain 10% of the chips you would have earned",
      onLoss = function(ctx)
          return math.floor((ctx.potentialScore or 0) * 0.1)
      end },

    { id = "perfect", name = "Perfectionist", rarity = 3, cost = 8, art = "21",
      desc = "Hand total is exactly 21: X2 Mult",
      onHand = function(ctx)
          if ctx.total == 21 then return { xmult = 2 } end
      end },

    { id = "bob", name = "Blackjack Bob", rarity = 3, cost = 8, art = "BJ",
      desc = "Natural Blackjack: X3 Mult",
      onHand = function(ctx)
          if ctx.natural then return { xmult = 3 } end
      end },

    { id = "momentum", name = "Momentum", rarity = 3, cost = 9, art = ">>",
      desc = function(inst)
          local n = inst.state.wins or 0
          return "Gains X0.1 Mult for every hand you win (now X" ..
              string.format("%.1f", 1 + 0.1 * n) .. ")"
      end,
      onHand = function(ctx, inst)
          local n = inst.state.wins or 0
          if n > 0 then return { xmult = 1 + 0.1 * n } end
      end,
      onHandEnd = function(ctx, inst)
          if ctx.result == "win" then inst.state.wins = (inst.state.wins or 0) + 1 end
      end },

    { id = "youstupid", name = "You Stupid!", rarity = 4, cost = 12, art = "9+10",
      desc = "A hand containing a 9 and a 10 value counts as 21",
      special21 = true },

    { id = "roller", name = "High Roller", rarity = 3, cost = 9, art = "X",
      desc = "X1.5 Mult",
      onHand = function() return { xmult = 1.5 } end },
}

J.byId = {}
for _, d in ipairs(J.list) do J.byId[d.id] = d end

J.rarityName = { "Common", "Uncommon", "Rare", "Epic" }

function J.new(id)
    return { id = id, def = J.byId[id], state = {} }
end

function J.describe(inst)
    local d = inst.def
    if type(d.desc) == "function" then return d.desc(inst) end
    return d.desc
end

function J.sellValue(inst)
    return math.max(1, math.floor(inst.def.cost / 2))
end

return J
