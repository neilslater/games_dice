# frozen_string_literal: true

require 'games_dice/prob_helpers'

module GamesDice
  # This class models probability distributions for dice systems.
  #
  # An object of this class represents a single distribution, which might be the result of a complex
  # combination of dice.
  #
  # @example Distribution for a six-sided die
  #  probs = GamesDice::Probabilities.for_fair_die( 6 )
  #  probs.min # => 1
  #  probs.max # => 6
  #  probs.expected # => 3.5
  #  probs.p_ge( 4 ) # => 0.5
  #
  # @example Adding two distributions
  #  pd6 = GamesDice::Probabilities.for_fair_die( 6 )
  #  probs = GamesDice::Probabilities.add_distributions( pd6, pd6 )
  #  probs.min # => 2
  #  probs.max # => 12
  #  probs.expected # => 7.0
  #  probs.p_ge( 10 ) # => 0.16666666666666669
  #
  class Probabilities
    include GamesDice::ProbabilityValidations
    include GamesDice::ProbabilityCalcSums
    extend GamesDice::ProbabilityCalcAddDistributions

    # Creates new instance of GamesDice::Probabilities.
    # @param [Array<Float>] probs Each entry in the array is the probability of getting a result
    # @param [Integer] offset The result associated with index of 0 in the array
    # @return [GamesDice::Probabilities]
    def initialize(probs = [1.0], offset = 0)
      # This should *probably* be validated in future, but that would impact performance
      @probs = check_probs_array probs.clone
      @offset = Integer(offset)
    end

    # Iterates through value, probability pairs
    # @yieldparam [Integer] result A result that may be possible in the dice scheme
    # @yieldparam [Float] probability Probability of result, in range 0.0..1.0
    # @return [GamesDice::Probabilities] this object
    def each
      @probs.each_with_index { |p, i| yield(i + @offset, p) if p > 0.0 }
      self
    end

    # A hash representation of the distribution. Each key is an integer result,
    # and the matching value is probability of getting that result. A new hash is generated on each
    # call to this method.
    # @return [Hash]
    def to_h
      GamesDice::Probabilities.prob_ao_to_h(@probs, @offset)
    end

    # @!attribute [r] min
    # Minimum result in the distribution
    # @return [Integer]
    def min
      @offset
    end

    # @!attribute [r] max
    # Maximum result in the distribution
    # @return [Integer]
    def max
      @offset + @probs.count - 1
    end

    # @!attribute [r] expected
    # Expected value of distribution.
    # @return [Float]
    def expected
      @expected ||= calc_expected
    end

    # Probability of result equalling specific target
    # @param [Integer] target
    # @return [Float] in range (0.0..1.0)
    def p_eql(target)
      i = Integer(target) - @offset
      return 0.0 if i.negative? || i >= @probs.count

      @probs[i]
    end

    # Probability of result being greater than specific target
    # @param [Integer] target
    # @return [Float] in range (0.0..1.0)
    def p_gt(target)
      p_ge(Integer(target) + 1)
    end

    # Probability of result being equal to or greater than specific target
    # @param [Integer] target
    # @return [Float] in range (0.0..1.0)
    def p_ge(target)
      target = Integer(target)
      return @prob_ge[target] if @prob_ge && @prob_ge[target]

      @prob_ge ||= {}

      return 1.0 if target <= min
      return 0.0 if target > max

      @prob_ge[target] = @probs[target - @offset, @probs.count - 1].inject(0.0) { |so_far, p| so_far + p }
    end

    # Probability of result being equal to or less than specific target
    # @param [Integer] target
    # @return [Float] in range (0.0..1.0)
    def p_le(target)
      target = Integer(target)
      return @prob_le[target] if @prob_le && @prob_le[target]

      @prob_le ||= {}

      return 1.0 if target >= max
      return 0.0 if target < min

      @prob_le[target] = @probs[0, 1 + target - @offset].inject(0.0) { |so_far, p| so_far + p }
    end

    # Probability of result being less than specific target
    # @param [Integer] target
    # @return [Float] in range (0.0..1.0)
    def p_lt(target)
      p_le(Integer(target) - 1)
    end

    # Probability distribution derived from this one, where we know (or are only interested in
    # situations where) the result is greater than or equal to target.
    # @param [Integer] target
    # @return [GamesDice::Probabilities] new distribution.
    def given_ge(target)
      target = Integer(target)
      target = min if min > target
      p = p_ge(target)
      raise "There is no valid distribution given a result >= #{target}" unless p > 0.0

      mult = 1.0 / p
      new_probs = @probs[target - @offset, @probs.count - 1].map { |x| x * mult }
      GamesDice::Probabilities.new(new_probs, target)
    end

    # Probability distribution derived from this one, where we know (or are only interested in
    # situations where) the result is less than or equal to target.
    # @param [Integer] target
    # @return [GamesDice::Probabilities] new distribution.
    def given_le(target)
      target = Integer(target)
      target = max if max < target
      p = p_le(target)
      raise "There is no valid distribution given a result <= #{target}" unless p > 0.0

      mult = 1.0 / p
      new_probs = @probs[0..target - @offset].map { |x| x * mult }
      GamesDice::Probabilities.new(new_probs, @offset)
    end

    # Creates new instance of GamesDice::Probabilities.
    # @param [Hash] prob_hash A hash representation of the distribution, each key is an integer result,
    #   and the matching value is probability of getting that result
    # @return [GamesDice::Probabilities]
    def self.from_h(prob_hash)
      raise TypeError, 'from_h expected a Hash' unless prob_hash.is_a? Hash

      probs, offset = prob_h_to_ao(prob_hash)
      GamesDice::Probabilities.new(probs, offset)
    end

    # Distribution for a die with equal chance of rolling 1..N
    # @param [Integer] sides Number of sides on die
    # @return [GamesDice::Probabilities]
    def self.for_fair_die(sides)
      sides = Integer(sides)
      raise ArgumentError, 'sides must be at least 1' unless sides.positive?
      raise ArgumentError, 'sides can be at most 100000' if sides > 100_000

      GamesDice::Probabilities.new(Array.new(sides, 1.0 / sides), 1)
    end

    # Combines two distributions to create a third, that represents the distribution created when adding
    # results together.
    # @param [GamesDice::Probabilities] pd_a First distribution
    # @param [GamesDice::Probabilities] pd_b Second distribution
    # @return [GamesDice::Probabilities]
    def self.add_distributions(pd_a, pd_b)
      check_is_gdp(pd_a, pd_b)
      combined_min = pd_a.min + pd_b.min
      combined_max = pd_a.max + pd_b.max

      add_distributions_internal(combined_min, combined_max, 1, pd_a, 1, pd_b)
    end

    # Combines two distributions with multipliers to create a third, that represents the distribution
    # created when adding weighted results together.
    # @param [Integer] m_a Weighting for first distribution
    # @param [GamesDice::Probabilities] pd_a First distribution
    # @param [Integer] m_b Weighting for second distribution
    # @param [GamesDice::Probabilities] pd_b Second distribution
    # @return [GamesDice::Probabilities]
    def self.add_distributions_mult(m_a, pd_a, m_b, pd_b)
      check_is_gdp(pd_a, pd_b)
      m_a = Integer(m_a)
      m_b = Integer(m_b)

      combined_min, combined_max = calc_combined_extremes(m_a, pd_a, m_b, pd_b).minmax

      add_distributions_internal(combined_min, combined_max, m_a, pd_a, m_b, pd_b)
    end

    # Returns a symbol for the language name that this class is implemented in. The C version of the
    # code is noticeably faster when dealing with larger numbers of possible results.
    # @return [Symbol] Either :c or :ruby
    def self.implemented_in
      :ruby
    end

    # Adds a distribution to itself repeatedly, to simulate a number of dice
    # results being summed.
    # @param [Integer] num_reps Number of repetitions, must be at least 1
    # @return [GamesDice::Probabilities] new distribution
    def repeat_sum(num_reps)
      num_reps = Integer(num_reps)
      raise 'Cannot combine probabilities less than once' if num_reps < 1
      raise 'Probability distribution too large' if (num_reps * @probs.count) > 1_000_000

      repeat_sum_internal(num_reps)
    end

    # Calculates distribution generated by summing best k results of n iterations
    # of the distribution.
    # @param [Integer] num_reps Number of repetitions, must be at least 1
    # @param [Integer] keep Number of best results to keep and sum
    # @return [GamesDice::Probabilities] new distribution
    def repeat_n_sum_k(num_reps, keep, kmode = :keep_best)
      num_reps = Integer(num_reps)
      keep = Integer(keep)
      raise 'Cannot combine probabilities less than once' if num_reps < 1
      # Technically this is a limitation of C code, but Ruby version is most likely slow and inaccurate beyond 170
      raise 'Too many dice to calculate numbers of arrangements' if num_reps > 170

      check_keep_mode(kmode)
      repeat_n_sum_k_internal(num_reps, keep, kmode)
    end
  end
end
