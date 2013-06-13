# This class models a combination of GamesDice::Bunch objects plus a fixed offset.
#
# An object of this class is a dice "recipe" that specifies the numbers and types of
# dice that can be rolled to generate an integer value.
#
# @example '3d6+6' hitpoints, whatever that means in the game you are playing
#  d = GamesDice::Dice.new( [{:ndice => 3, :sides => 6}], 6, 'Hit points' )
#  d.roll # => 20
#  d.result # => 20
#  d.explain_result # => "3d6: 3 + 5 + 6 = 14. 14 + 6 = 20"
#  d.probabilities.expected # => 16.5
#
# @example Roll d20 twice, take best result, and add 5.
#  d = GamesDice::Dice.new( [{:ndice => 2, :sides => 20 , :keep_mode => :keep_best, :keep_number => 1}], 5 )
#  d.roll # => 21
#  d.result # => 21
#  d.explain_result # => "2d20: 4, 16. Keep: 16. 16 + 5 = 21"
#
class GamesDice::Dice
  # The first parameter is an array of values that are passed to GamesDice::Bunch constructors.
  # @param [Array<Hash>] bunches Array of options for creating bunches
  # @param [Integer] offset Total offset
  # @param [String] name Optional label for the dice
  # @option bunches [Integer] :ndice Number of dice in the bunch, *mandatory*
  # @option bunches [Integer] :sides Number of sides on a single die in the bunch, *mandatory*
  # @option bunches [String] :name Optional name for the bunch
  # @option bunches [Array<GamesDice::RerollRule,Array>] :rerolls Optional rules that cause the die to roll again
  # @option bunches [Array<GamesDice::MapRule,Array>] :maps Optional rules to convert a value into a final result for the die
  # @option bunches [#rand] :prng Optional alternative source of randomness to Ruby's built-in #rand, passed to GamesDice::Die's constructor
  # @option bunches [Symbol] :keep_mode Optional, either *:keep_best* or *:keep_worst*
  # @option bunches [Integer] :keep_number Optional number of dice to keep when :keep_mode is not nil
  # @option bunches [Integer] :multiplier Optional, defaults to 1, and typically 1 or -1 to describe whether the Bunch total is to be added or subtracted
  # @return [GamesDice::Dice]
  def initialize( bunches, offset = 0, name = '' )
    @name = name
    @offset = offset
    @bunches = bunches.map { |b| GamesDice::Bunch.new( b ) }
    @bunch_multipliers = bunches.map { |b| b[:multiplier] || 1 }
    @result = nil
  end

  # Name to help identify dice
  # @return [String]
  attr_reader :name

  # Bunches of dice that are components of the object
  # @return [Array<GamesDice::Bunch>]
  attr_reader :bunches

  # Multipliers for each bunch of identical dice. Typically 1 or -1 to represent groups of dice that
  # are either added or subtracted from the total.
  # @return [Array<Integer>]
  attr_reader :bunch_multipliers

  # Fixed offset added to sum of all bunches.
  # @return [Integer]
  attr_reader :offset

  # Result of most-recent roll, or nil if no roll made yet.
  # @return [Integer,nil]
  attr_reader :result

  # Simulates rolling dice
  # @return [Integer] Sum of all rolled dice
  def roll
    @result = @offset + @bunch_multipliers.zip(@bunches).inject(0) do |total,mb|
      m,b = mb
      total += m * b.roll
    end
  end

  # @!attribute [r] min
  # Minimum possible result from a call to #roll
  # @return [Integer]
  def min
    @min ||= @offset + @bunch_multipliers.zip(@bunches).inject(0) do |total,mb|
      m,b = mb
      total += m * b.min
    end
  end

  # @!attribute [r] max
  # Maximum possible result from a call to #roll
  # @return [Integer]
  def max
    @max ||= @offset + @bunch_multipliers.zip(@bunches).inject(0) do |total,mb|
      m,b = mb
      total += m * b.max
    end
  end

  # @!attribute [r] minmax
  # Convenience method, same as [dice.min, dice.max]
  # @return [Array<Integer>]
  def minmax
    [min,max]
  end

  # Calculates the probability distribution for the dice. When the dice include components with
  # open-ended re-roll rules, there are some arbitrary limits imposed to prevent large amounts of
  # recursion.
  # @return [GamesDice::Probabilities] Probability distribution of dice.
  def probabilities
    return @probabilities if @probabilities
    probs = @bunch_multipliers.zip(@bunches).inject( GamesDice::Probabilities.new( [1.0], @offset ) ) do |probs, mb|
      m,b = mb
      GamesDice::Probabilities.add_distributions_mult( 1, probs, m, b.probabilities )
    end
  end

  # @!attribute [r] explain_result
  # @return [String,nil] Explanation of result, or nil if no call to #roll yet.
  def explain_result
    return nil unless @result
    explanations = @bunches.map { |bunch| bunch.label + ": " + bunch.explain_result }

    if explanations.count == 0
      return @offset.to_s
    end

    if explanations.count == 1
      if @offset !=0
        return explanations[0] + '. ' + array_to_sum( [ @bunches[0].result, @offset ] )
      else
        return explanations[0]
      end
    end

    bunch_values = @bunch_multipliers.zip(@bunches).map { |m,b| m * b.result }
    bunch_values << @offset if @offset != 0
    explanations << array_to_sum( bunch_values )
    return explanations.join('. ')
  end

  private

  def array_to_sum array
    sum_parts = [ array.first < 0 ? '-' + array.first.abs.to_s : array.first.to_s ]
    sum_parts += array.drop(1).map { |n| n < 0 ? '- ' + n.abs.to_s : '+ ' + n.to_s }
    sum_parts += [ '=', array.inject(:+) ]
    sum_parts.join(' ')
  end

end # class Dice
