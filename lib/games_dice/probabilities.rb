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
class GamesDice::Probabilities

  # Creates new instance of GamesDice::Probabilities.
  # @param [Hash] prob_hash A hash representation of the distribution, each key is an integer result,
  #   and the matching value is probability of getting that result
  # @return [GamesDice::Probabilities]
  def initialize( prob_hash = { 0 => 1.0 } )
    # This should *probably* be validated in future, but that would impact performance
    @ph = prob_hash
  end

  # @!visibility private
  # the Hash representation of probabilities.
  attr_reader :ph

  # A hash representation of the distribution. Each key is an integer result,
  # and the matching value is probability of getting that result. A new hash is generated on each
  # call to this method.
  # @return [Hash]
  def to_h
    @ph.clone
  end

  # @!attribute [r] min
  # Minimum result in the distribution
  # @return [Integer]
  def min
    (@minmax ||= @ph.keys.minmax )[0]
  end

  # @!attribute [r] max
  # Maximum result in the distribution
  # @return [Integer]
  def max
    (@minmax ||= @ph.keys.minmax )[1]
  end

  # @!attribute [r] expected
  # Expected value of distribution.
  # @return [Float]
  def expected
    @expected ||= @ph.inject(0.0) { |accumulate,p| accumulate + p[0] * p[1] }
  end

  # Probability of result equalling specific target
  # @param [Integer] target
  # @return [Float] in range (0.0..1.0)
  def p_eql target
    @ph[ Integer(target) ] || 0.0
  end

  # Probability of result being greater than specific target
  # @param [Integer] target
  # @return [Float] in range (0.0..1.0)
  def p_gt target
    p_ge( Integer(target) + 1 )
  end

  # Probability of result being equal to or greater than specific target
  # @param [Integer] target
  # @return [Float] in range (0.0..1.0)
  def p_ge target
    target = Integer(target)
    return @prob_ge[target] if @prob_ge && @prob_ge[target]
    @prob_ge = {} unless @prob_ge

    return 1.0 if target <= min
    return 0.0 if target > max
    @prob_ge[target] = @ph.select {|k,v| target <= k}.inject(0.0) {|so_far,pv| so_far + pv[1] }
  end

  # Probability of result being equal to or less than specific target
  # @param [Integer] target
  # @return [Float] in range (0.0..1.0)
  def p_le target
    target = Integer(target)
    return @prob_le[target] if @prob_le && @prob_le[target]
    @prob_le = {} unless @prob_le

    return 1.0 if target >= max
    return 0.0 if target < min
    @prob_le[target] = @ph.select {|k,v| target >= k}.inject(0.0) {|so_far,pv| so_far + pv[1] }
  end

  # Probability of result being less than specific target
  # @param [Integer] target
  # @return [Float] in range (0.0..1.0)
  def p_lt target
    p_le( Integer(target) - 1 )
  end

  # Distribution for a die with equal chance of rolling 1..N
  # @param [Integer] sides Number of sides on die
  # @return [GamesDice::Probabilities]
  def self.for_fair_die sides
    sides = Integer(sides)
    raise ArgumentError, "sides must be at least 1" unless sides > 0
    h = {}
    p = 1.0/sides
    (1..sides).each { |x| h[x] = p }
    GamesDice::Probabilities.new( h )
  end

  # Combines two distributions to create a third, that represents the distribution created when adding
  # results together.
  # @param [GamesDice::Probabilities] pd_a First distribution
  # @param [GamesDice::Probabilities] pd_b Second distribution
  # @return [GamesDice::Probabilities]
  def self.add_distributions pd_a, pd_b
    h = {}
    pd_a.ph.each do |ka,pa|
      pd_b.ph.each do |kb,pb|
        kc = ka + kb
        pc = pa * pb
        h[kc] = h[kc] ? h[kc] + pc : pc
      end
    end
    GamesDice::Probabilities.new( h )
  end

  # Combines two distributions with multipliers to create a third, that represents the distribution
  # created when adding weighted results together.
  # @param [Integer] m_a Weighting for first distribution
  # @param [GamesDice::Probabilities] pd_a First distribution
  # @param [Integer] m_b Weighting for second distribution
  # @param [GamesDice::Probabilities] pd_b Second distribution
  # @return [GamesDice::Probabilities]
  def self.add_distributions_mult m_a, pd_a, m_b, pd_b
    h = {}
    pd_a.ph.each do |ka,pa|
      pd_b.ph.each do |kb,pb|
        kc = m_a * ka + m_b * kb
        pc = pa * pb
        h[kc] = h[kc] ? h[kc] + pc : pc
      end
    end
    GamesDice::Probabilities.new( h )
  end

end # class GamesDice::Probabilities
