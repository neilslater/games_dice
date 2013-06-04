require "games_dice/version"
require "games_dice/constants"
require "games_dice/probabilities"
require "games_dice/die"
require "games_dice/die_result"
require "games_dice/reroll_rule"
require "games_dice/map_rule"
require "games_dice/complex_die"
require "games_dice/bunch"
require "games_dice/dice"
require "games_dice/parser"

module GamesDice
  # @!visibility private
  @@parser = GamesDice::Parser.new

  def self.create dice_description, prng = nil
    parsed = @@parser.parse( dice_description )
    GamesDice::Dice.new( parsed[:bunches], parsed[:offset], prng )
  end
end
