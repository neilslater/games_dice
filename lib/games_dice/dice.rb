# frozen_string_literal: true

require 'games_dice/dice_helpers'

module GamesDice
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
  class Dice
    include RecipeQueries
    include ProbabilityHelpers

    # The first parameter is an array of values that are passed to GamesDice::Bunch constructors.
    # @param [Array<Hash>] bunches Array of options for creating bunches
    # @param [Integer] offset Total offset
    # @param [String] name Optional label for the dice
    # @option bunches [Integer] :ndice Number of dice in the bunch, *mandatory*
    # @option bunches [Integer] :sides Number of sides on a single die in the bunch, *mandatory*
    # @option bunches [String] :name Optional name for the bunch
    # @option bunches [Array<GamesDice::RerollRule,Array>] :rerolls Optional rules that cause the die to roll again
    # @option bunches [Array<GamesDice::MapRule,Array>] :maps Optional rules to convert a value into a final result
    #   for the die
    # @option bunches [#rand] :prng Optional alternative source of randomness to Ruby's built-in #rand, passed to
    #   GamesDice::Die's constructor
    # @option bunches [Symbol] :keep_mode Optional, either *:keep_best* or *:keep_worst*
    # @option bunches [Integer] :keep_number Optional number of dice to keep when :keep_mode is not nil
    # @option bunches [Integer] :multiplier Optional, defaults to 1, and typically 1 or -1 to describe whether the
    #   Bunch total is to be added or subtracted
    # @return [GamesDice::Dice]
    def initialize(bunches, offset = 0, name = '')
      @name = name
      @offset = offset
      @bunches = bunches.map { |b| GamesDice::Bunch.new(b) }
      @bunch_multipliers = bunches.map { |b| b[:multiplier] || 1 }
      @result = nil
      initialize_recipe
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
    def result
      refresh_recipe
      @result
    end

    # Simulates rolling dice
    # @return [Integer] Sum of all rolled dice
    def roll
      with_recipe { @result = @offset + bunches_weighted_sum(:roll) }
    end

    # @!attribute [r] min
    # Lower bound on the value returned by #roll. No roll will be below this value.
    # For some complex dice, this may be lower than any value that can actually
    # be rolled, because calculating the exact minimum would take too much work.
    # @return [Integer]
    def min
      refresh_recipe
      @min ||= with_recipe { @offset + weighted_bound(:min, :max) }
    end

    # @!attribute [r] max
    # Upper bound on the value returned by #roll. No roll will exceed this value.
    # For some complex dice, this may be higher than any value that can actually
    # be rolled, because calculating the exact maximum would take too much work.
    # @return [Integer]
    def max
      refresh_recipe
      @max ||= with_recipe { @offset + weighted_bound(:max, :min) }
    end

    # @!attribute [r] minmax
    # Convenience method, same as [dice.min, dice.max]
    # @return [Array<Integer>]
    def minmax
      [min, max]
    end

    # Calculates the probability distribution for the combined dice result.
    #
    # Very unlikely sequences of rerolls may be left out to keep calculation
    # time reasonable. This changes the probability of any combined result by
    # at most 1e-10 (one in ten billion), in addition to normal floating-point
    # rounding. This limit covers all the bunches together.
    #
    # Raises ProbabilityLimitError if this accuracy cannot be achieved within
    # the calculation's work limits.
    # @return [GamesDice::Probabilities] Probability distribution of the dice.
    def probabilities
      refresh_recipe
      return @probabilities if valid_probability_cache?(ProbabilityBudget::LIMIT)

      @probabilities = with_recipe { combined_probabilities }
    end

    # @!attribute [r] explain_result
    # @return [String,nil] Explanation of result, or nil if no call to #roll yet.
    def explain_result
      refresh_recipe
      return nil unless @result

      explanations = @bunches.map { |bunch| "#{bunch.label}: #{bunch.explain_result}" }

      return @offset.to_s if explanations.none?

      return simple_explanation(explanations.first) if explanations.one?

      multi_explanations(explanations)
    end

    private

    def recipe_sources
      [[@bunches, Bunch], [@bunch_multipliers, Numeric]]
    end

    def recipe_labels
      [@name]
    end

    def validate_recipe
      return if @bunches.length == @bunch_multipliers.length

      raise ArgumentError, 'bunches and bunch_multipliers must have the same length'
    end

    def weighted_bound(positive, negative)
      @bunches.zip(@bunch_multipliers).sum do |bunch, multiplier|
        next 0 if multiplier.zero?

        multiplier * bunch.public_send(multiplier.negative? ? negative : positive)
      end
    end

    def simple_explanation(explanation)
      return explanation if @offset.zero? && @bunch_multipliers[0] == 1

      values = [@bunch_multipliers[0] * @bunches[0].result]
      values << @offset unless @offset.zero?
      "#{explanation}. #{array_to_sum(values)}"
    end

    def multi_explanations(explanations)
      bunch_values = @bunch_multipliers.zip(@bunches).map { |m, b| m * b.result }
      bunch_values << @offset if @offset != 0
      explanations << array_to_sum(bunch_values)
      explanations.join('. ')
    end

    def array_to_sum(array)
      (numbers_to_strings(array) + ['=', array.sum]).join(' ')
    end

    def numbers_to_strings(array)
      [array.first.to_s] + array.drop(1).map { |n| n.negative? ? "- #{n.abs}" : "+ #{n}" }
    end

    def bunches_weighted_sum(summed_method)
      @bunch_multipliers.zip(@bunches).inject(0) do |total, mb|
        m, b = mb
        total + (m * b.send(summed_method))
      end
    end
  end
end
