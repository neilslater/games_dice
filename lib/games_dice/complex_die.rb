# frozen_string_literal: true

require 'games_dice/complex_die_helpers'
require 'games_dice/probability_calculation'

module GamesDice
  # This class models a die that is built up from a simpler unit by adding rules to re-roll
  # and interpret the value shown.
  #
  # An object of this class represents a single complex die. It rolls 1..#sides, with equal weighting
  # for each value. The value from a roll may be used to trigger yet more rolls that combine together.
  # After any re-rolls, the value can be interpretted ("mapped") as another integer, which is used as
  # the final result.
  #
  # @example An open-ended percentile die from a popular RPG
  #  d = GamesDice::ComplexDie.new( 100, :rerolls => [[96, :<=, :reroll_add],[5, :>=, :reroll_subtract]] )
  #  d.roll # => #<GamesDice::DieResult:0x007ff03a2415f8 @rolls=[4, 27], ...>
  #  d.result.value # => -23
  #  d.explain_result # => "[4-27] -23"
  #
  # @example An "exploding" six-sided die with a target number
  #  d = GamesDice::ComplexDie.new( 6, :rerolls => [[6, :<=, :reroll_add]], :maps => [[8, :<=, 1, 'Success']] )
  #  d.roll # => #<GamesDice::DieResult:0x007ff03a1e8e08 @rolls=[6, 5], ...>
  #  d.result.value # => 1
  #  d.explain_result # => "[6+5] 11 Success"
  #
  class ComplexDie
    include RollHelpers
    include RecipeQueries
    include ProbabilityHelpers
    include MinMaxHelpers

    # @!visibility private
    # arbitrary limit to speed up probability calculations. It should
    # be larger than anything seen in real-world tabletop games.
    MAX_REROLLS = 1000

    # Creates new instance of GamesDice::ComplexDie
    # @param [Integer] sides Number of sides on a single die, passed to GamesDice::Die's constructor
    # @param [Hash] options
    # @option options [Array<GamesDice::RerollRule,Array>] :rerolls The rules that cause the die to roll again
    # @option options [Array<GamesDice::MapRule,Array>] :maps The rules to convert a value into a final result
    #    for the die
    # @option options [#rand] :prng An alternative source of randomness to Ruby's built-in #rand, passed to
    #    GamesDice::Die's constructor
    # @return [GamesDice::ComplexDie]
    def initialize(sides, options = {})
      @basic_die = GamesDice::Die.new(sides, options[:prng])

      @rerolls = construct_rerolls(options[:rerolls])
      @maps = construct_maps(options[:maps])

      @total = nil
      @result = nil

      initialize_recipe
      @probabilities_complete = true
    end

    # The simple component used by this complex one
    # @return [GamesDice::Die] Object used to make individual dice rolls for the complex die
    attr_reader :basic_die

    # @return [Array<GamesDice::RerollRule>, nil] Sequence of re-roll rules, or nil if re-rolls are not required.
    attr_reader :rerolls

    # @return [Array<GamesDice::MapRule>, nil] Sequence of map rules, or nil if mapping is not required.
    attr_reader :maps

    # @return [GamesDice::DieResult, nil] Result of last call to #roll, nil if no call made yet
    def result
      refresh_recipe
      @result
    end

    # Whether the probability calculation included all possible sequences of rerolls.
    # After calling #probabilities, true means none were left out. False means
    # very unlikely sequences were skipped to keep calculation time reasonable.
    # Even when false, this changes the probability of any result by at most
    # 1e-10 (one in ten billion), in addition to normal floating-point rounding.
    #
    # Call #probabilities before checking this value. A new die starts with true,
    # even though no calculation has run yet.
    # @return [Boolean, nil] Whether the calculation is complete, or nil if its
    #   result was cleared after a recipe change or a failed calculation.
    def probabilities_complete
      refresh_recipe
      @probabilities_complete
    end

    # @!attribute [r] sides
    # @return [Integer] Number of sides.
    def sides
      @basic_die.sides
    end

    # @!attribute [r] explain_result
    # @return [String,nil] Explanation of result, or nil if no call to #roll yet.
    def explain_result
      refresh_recipe
      @result&.explain_value
    end

    # Lower bound on the numeric value of a roll (#roll.value).
    # No roll will have a value below this bound.
    # For some complex dice, this may be lower than any value that can actually
    # be rolled, because calculating the exact minimum would take too much work.
    #
    # Raises ProbabilityLimitError if a lower bound cannot be found within
    # the calculation's work limits.
    # @!attribute [r] min
    # @return [Integer]
    def min
      refresh_recipe
      return @min_result if @min_result

      with_recipe { calc_minmax }
      @min_result
    end

    # Upper bound on the numeric value of a roll (#roll.value).
    # No roll will have a value above this bound.
    # For some complex dice, this may be higher than any value that can actually
    # be rolled, because calculating the exact maximum would take too much work.
    #
    # Raises ProbabilityLimitError if an upper bound cannot be found within
    # the calculation's work limits.
    # @!attribute [r] max
    # @return [Integer]
    def max
      refresh_recipe
      return @max_result if @max_result

      with_recipe { calc_minmax }
      @max_result
    end

    # Calculates the probability distribution for the die.
    #
    # Very unlikely sequences of rerolls may be left out to keep calculation
    # time reasonable. This changes the probability of any result by at most
    # 1e-10 (one in ten billion), in addition to normal floating-point rounding.
    #
    # Raises ProbabilityLimitError if this accuracy cannot be achieved within
    # the calculation's work limits.
    # @return [GamesDice::Probabilities] Probability distribution of the die.
    def probabilities
      probabilities_for_budget(ProbabilityBudget::LIMIT)
    end

    # Simulates rolling the die
    # @param [Symbol] reason Assign a reason for rolling the first die.
    # @return [GamesDice::DieResult] Detailed results from rolling the die, including resolution of rules.
    def roll(reason = :basic)
      with_recipe do
        rerolls = @rerolls&.dup
        maps = @maps&.dup
        @result = GamesDice::DieResult.new(@basic_die.roll, reason)
        roll_apply_rerolls(rerolls)
        roll_apply_maps(maps)
        @result
      end
    end

    private

    def recipe_sources
      [[@rerolls, RerollRule], [@maps, MapRule]]
    end

    def construct_rerolls(rerolls_input)
      check_and_construct rerolls_input, GamesDice::RerollRule, 'rerolls'
    end

    def construct_maps(maps_input)
      check_and_construct maps_input, GamesDice::MapRule, 'maps'
    end

    def check_and_construct(input, klass, label)
      return nil unless input
      raise TypeError, "#{label} should be an Array, instead got #{input.inspect}" unless input.is_a?(Array)

      input.map do |i|
        case i
        when Array then klass.new(*i)
        when klass then i
        else
          raise TypeError, "items in #{label} should be #{klass.name} or Array, instead got #{i.inspect}"
        end
      end
    end
  end
end
