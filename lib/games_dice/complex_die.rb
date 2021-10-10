# frozen_string_literal: true

require 'games_dice/complex_die_helpers'

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
    attr_reader :result

    # Whether or not #probabilities includes all possible outcomes.
    # True if all possible results are represented and assigned a probability. Dice with open-ended re-rolls
    # may have calculations cut short, and will result in a false value of this attribute. Even when this
    # attribute is false, probabilities should still be accurate to nearest 1e-9.
    # @return [Boolean, nil] Depending on completeness when generating #probabilities
    attr_reader :probabilities_complete

    # @!attribute [r] sides
    # @return [Integer] Number of sides.
    def sides
      @basic_die.sides
    end

    # @!attribute [r] explain_result
    # @return [String,nil] Explanation of result, or nil if no call to #roll yet.
    def explain_result
      @result.explain_value
    end

    # The minimum possible result from a call to #roll. This is not always the same as the theoretical
    # minimum, due to limits on the maximum number of rerolls.
    # @!attribute [r] min
    # @return [Integer]
    def min
      return @min_result if @min_result

      calc_minmax
      @min_result
    end

    # @!attribute [r] max
    # @return [Integer] Maximum possible result from a call to #roll
    def max
      return @max_result if @max_result

      calc_minmax
      @max_result
    end

    # Calculates the probability distribution for the die. For open-ended re-roll rules, there are some
    # arbitrary limits imposed to prevent large amounts of recursion. Probabilities should be to nearest
    # 1e-9 at worst.
    # @return [GamesDice::Probabilities] Probability distribution of die.
    def probabilities
      @probabilities ||= calculate_probabilities
    end

    # Simulates rolling the die
    # @param [Symbol] reason Assign a reason for rolling the first die.
    # @return [GamesDice::DieResult] Detailed results from rolling the die, including resolution of rules.
    def roll(reason = :basic)
      @result = GamesDice::DieResult.new(@basic_die.roll, reason)
      roll_apply_rerolls
      roll_apply_maps
      @result
    end

    private

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
