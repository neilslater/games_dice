require "games_dice/version"
begin
  require "games_dice/games_dice"
rescue LoadError
  require "games_dice/probabilities"
end
require "games_dice/constants"
require "games_dice/die"
require "games_dice/die_result"
require "games_dice/reroll_rule"
require "games_dice/map_rule"
require "games_dice/complex_die"
require "games_dice/bunch"
require "games_dice/dice"
require "games_dice/parser"
require "games_dice/marshal"

module GamesDice
  # @!visibility private
  @@parser = GamesDice::Parser.new

  # Creates an instance of GamesDice::Dice from a string description.
  # @param [String] dice_description Uses a variation of common game notation, examples: '1d6', '3d8+1d4+7', '5d10k2'
  # @param [#rand] prng Optional random number generator, default is to use Ruby's built-in #rand()
  # @return [GamesDice::Dice] A new dice object.
  #
  def self.create dice_description, prng = nil
    parsed = @@parser.parse( dice_description )
    GamesDice::Dice.new( parsed[:bunches], parsed[:offset], prng )
  end
end
