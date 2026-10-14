# frozen_string_literal: true

require 'games_dice/bunch_helpers'

module GamesDice
  # This class models a number of identical dice, which may be either GamesDice::Die or
  # GamesDice::ComplexDie objects.
  #
  # An object of this class represents a fixed number of indentical dice that may be rolled and their
  # values summed to make a total for the bunch.
  #
  # @example The ubiquitous '3d6'
  #  d = GamesDice::Bunch.new( :ndice => 3, :sides => 6 )
  #  d.roll # => 14
  #  d.result # => 14
  #  d.explain_result # => "2 + 6 + 6 = 14"
  #  d.max # => 18
  #
  # @example Roll 5d10, and keep the best 2
  #  d = GamesDice::Bunch.new( :ndice => 5, :sides => 10 , :keep_mode => :keep_best, :keep_number => 2 )
  #  d.roll # => 18
  #  d.result # => 18
  #  d.explain_result # => "4, 9, 2, 9, 1. Keep: 9 + 9 = 18"
  #
  class Bunch
    include RecipeQueries
    include ProbabilityHelpers
    include KeepHelpers
    include ExplainHelpers

    # The constructor accepts parameters that are suitable for either GamesDice::Die or GamesDice::ComplexDie
    # and decides which of those classes to instantiate.
    # @param [Hash] options
    # @option options [Integer] :ndice Number of dice in the bunch, *mandatory*
    # @option options [Integer] :sides Number of sides on a single die in the bunch, *mandatory*
    # @option options [String] :name Optional name for the bunch
    # @option options [Array<GamesDice::RerollRule,Array>] :rerolls Optional rules that cause the die to roll again
    # @option options [Array<GamesDice::MapRule,Array>] :maps Optional rules to convert a value into a final result
    #   for the die
    # @option options [#rand] :prng Optional alternative source of randomness to Ruby's built-in #rand, passed to
    #   GamesDice::Die's constructor
    # @option options [Symbol] :keep_mode Optional, either *:keep_best* or *:keep_worst*
    # @option options [Integer] :keep_number Optional number of dice to keep when :keep_mode is not nil
    # @return [GamesDice::Bunch]
    def initialize(options)
      name_number_sides_from_hash(options)
      keep_mode_from_hash(options)

      raise ':prng does not support the rand() method' if options[:prng] && !options[:prng].respond_to?(:rand)

      @single_die = if options[:rerolls] || options[:maps]
                      GamesDice::ComplexDie.new(@sides, complex_die_params_from_hash(options))
                    else
                      GamesDice::Die.new(@sides, options[:prng])
                    end
      initialize_recipe
    end

    # Name to help identify bunch
    # @return [String]
    attr_reader :name

    # Number of dice to roll
    # @return [Integer]
    attr_reader :ndice

    # Individual die from the bunch
    # @return [GamesDice::Die,GamesDice::ComplexDie]
    attr_reader :single_die

    # Can be nil, :keep_best or :keep_worst
    # @return [Symbol,nil]
    attr_reader :keep_mode

    # Number of "best" or "worst" results to select when #keep_mode is not nil.
    # @return [Integer,nil]
    attr_reader :keep_number

    # Result of most-recent roll, or nil if no roll made yet.
    # @return [Integer,nil]
    def result
      refresh_recipe
      @result
    end

    # @!attribute [r] label
    # Description that will be used in explanations with more than one bunch
    # @return [String]
    def label
      return @name if @name != ''

      "#{@ndice}d#{@sides}"
    end

    # @!attribute [r] rerolls
    # Sequence of re-roll rules, or nil if re-rolls are not required.
    # @return [Array<GamesDice::RerollRule>, nil]
    def rerolls
      @single_die.rerolls
    end

    # @!attribute [r] maps
    # Sequence of map rules, or nil if mapping is not required.
    # @return [Array<GamesDice::MapRule>, nil]
    def maps
      @single_die.maps
    end

    # @!attribute [r] result_details
    # After calling #roll, this is an array of GamesDice::DieResult objects. There is one from each #single_die rolled,
    # allowing inspection of how the result was obtained.
    # @return [Array<GamesDice::DieResult>, nil] Sequence of GamesDice::DieResult objects.
    def result_details
      refresh_recipe
      return nil unless @raw_result_details

      @raw_result_details.map { |r| r.is_a?(Integer) ? GamesDice::DieResult.new(r) : r }
    end

    # @!attribute [r] min
    # Lower bound on the value returned by #roll. No roll will be below this value.
    # For some complex dice, this may be lower than any value that can actually
    # be rolled, because calculating the exact minimum would take too much work.
    # @return [Integer]
    def min
      refresh_recipe
      n = @keep_mode ? [@keep_number, @ndice].min : @ndice
      n * @single_die.min
    end

    # @!attribute [r] max
    # Upper bound on the value returned by #roll. No roll will exceed this value.
    # For some complex dice, this may be higher than any value that can actually
    # be rolled, because calculating the exact maximum would take too much work.
    # @return [Integer]
    def max
      refresh_recipe
      n = @keep_mode ? [@keep_number, @ndice].min : @ndice
      n * @single_die.max
    end

    # Calculates the probability distribution for the bunch.
    #
    # Very unlikely sequences of rerolls may be left out to keep calculation
    # time reasonable. This changes the probability of any result by at most
    # 1e-10 (one in ten billion) across the whole bunch, in addition to normal
    # floating-point rounding.
    #
    # Raises ProbabilityLimitError if this accuracy cannot be achieved within
    # the calculation's work limits.
    # @return [GamesDice::Probabilities] Probability distribution of the bunch.
    def probabilities
      probabilities_for_budget(ProbabilityBudget::LIMIT)
    end

    # Simulates rolling the bunch of identical dice
    # @return [Integer] Sum of all rolled dice, or sum of all keepers
    def roll
      with_recipe do
        generate_raw_results
        @used_result_details = select_keepers
        @result = @used_result_details.sum
      end
    end

    # @!attribute [r] explain_result
    # Explanation of result, or nil if no call to #roll yet.
    # @return [String,nil]
    def explain_result
      refresh_recipe
      return nil unless @result

      used_dice = @used_result_details.map { |result| result.is_a?(Integer) ? DieResult.new(result) : result }
      build_explanation(used_dice)
    end

    private

    def recipe_sources
      [[[@single_die], @single_die.class]]
    end

    def recipe_labels
      [@name]
    end

    def select_keepers
      return @raw_result_details if !@keep_mode || @keep_number >= @ndice
      return @raw_result_details.sort[-@keep_number..] if @keep_mode == :keep_best

      @raw_result_details.sort[0...@keep_number]
    end

    def generate_raw_results
      @raw_result_details = Array.new(@ndice) { @single_die.roll }
    end

    def name_number_sides_from_hash(options)
      @name = options[:name].to_s
      @ndice = Integer(options[:ndice])
      raise ArgumentError, ":ndice must be 1 or more, but got #{@ndice}" unless @ndice.positive?

      @sides = Integer(options[:sides])
      raise ArgumentError, ":sides must be 1 or more, but got #{@sides}" unless @sides.positive?
    end

    def complex_die_params_from_hash(options)
      cd_hash = {}
      %i[maps rerolls].each do |k|
        cd_hash[k] = options[k].clone if options[k]
      end
      # We deliberately do not clone this object, it will often be intended that it is shared
      cd_hash[:prng] = options[:prng]
      cd_hash
    end
  end
end
