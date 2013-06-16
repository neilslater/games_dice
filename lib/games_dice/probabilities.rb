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
  # @param [Array<Float>] probs Each entry in the array is the probability of getting a result
  # @param [Integer] offset The result associated with index of 0 in the array
  # @return [GamesDice::Probabilities]
  def initialize( probs = [1.0], offset = 0 )
    # This should *probably* be validated in future, but that would impact performance
    @probs = probs
    @offset = offset
  end

  # @!visibility private
  # the Array, Offset representation of probabilities.
  def to_ao
    [ @probs, @offset ]
  end

  # Iterates through value, probability pairs
  # @yieldparam [Integer] result A result that may be possible in the dice scheme
  # @yieldparam [Float] probability Probability of result, in range 0.0..1.0
  # @return [GamesDice::Probabilities] this object
  def each
    @probs.each_with_index { |p,i| yield( i+@offset, p ) }
    return self
  end

  # A hash representation of the distribution. Each key is an integer result,
  # and the matching value is probability of getting that result. A new hash is generated on each
  # call to this method.
  # @return [Hash]
  def to_h
    GamesDice::Probabilities.prob_ao_to_h( @probs, @offset )
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
    @offset + @probs.count() - 1
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
  def p_eql target
    i = Integer(target) - @offset
    return 0.0 if i < 0 || i >= @probs.count
    @probs[ i ]
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
    @prob_ge[target] = @probs[target-@offset,@probs.count-1].inject(0.0) {|so_far,p| so_far + p }
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
    @prob_le[target] = @probs[0,1+target-@offset].inject(0.0) {|so_far,p| so_far + p }
  end

  # Probability of result being less than specific target
  # @param [Integer] target
  # @return [Float] in range (0.0..1.0)
  def p_lt target
    p_le( Integer(target) - 1 )
  end

  # Creates new instance of GamesDice::Probabilities.
  # @param [Hash] prob_hash A hash representation of the distribution, each key is an integer result,
  #   and the matching value is probability of getting that result
  # @return [GamesDice::Probabilities]
  def self.from_h prob_hash
    probs, offset = prob_h_to_ao( prob_hash )
    GamesDice::Probabilities.new( probs, offset )
  end

  # Distribution for a die with equal chance of rolling 1..N
  # @param [Integer] sides Number of sides on die
  # @return [GamesDice::Probabilities]
  def self.for_fair_die sides
    sides = Integer(sides)
    raise ArgumentError, "sides must be at least 1" unless sides > 0
    GamesDice::Probabilities.new( Array.new( sides, 1.0/sides ), 1 )
  end

  # Combines two distributions to create a third, that represents the distribution created when adding
  # results together.
  # @param [GamesDice::Probabilities] pd_a First distribution
  # @param [GamesDice::Probabilities] pd_b Second distribution
  # @return [GamesDice::Probabilities]
  def self.add_distributions pd_a, pd_b
    combined_min = pd_a.min + pd_b.min
    combined_max = pd_a.max + pd_b.max
    new_probs = Array.new( 1 + combined_max - combined_min, 0.0 )
    probs_a, offset_a = pd_a.to_ao
    probs_b, offset_b = pd_b.to_ao

    probs_a.each_with_index do |pa,i|
      probs_b.each_with_index do |pb,j|
        k = i + j
        pc = pa * pb
        new_probs[ k ] += pc
      end
    end
    GamesDice::Probabilities.new( new_probs, combined_min )
  end

  # Combines two distributions with multipliers to create a third, that represents the distribution
  # created when adding weighted results together.
  # @param [Integer] m_a Weighting for first distribution
  # @param [GamesDice::Probabilities] pd_a First distribution
  # @param [Integer] m_b Weighting for second distribution
  # @param [GamesDice::Probabilities] pd_b Second distribution
  # @return [GamesDice::Probabilities]
  def self.add_distributions_mult m_a, pd_a, m_b, pd_b
    combined_min, combined_max = [
      m_a * pd_a.min + m_b * pd_b.min, m_a * pd_a.max + m_b * pd_b.min,
      m_a * pd_a.min + m_b * pd_b.max, m_a * pd_a.max + m_b * pd_b.max,
      ].minmax

    new_probs = Array.new( 1 + combined_max - combined_min, 0.0 )
    probs_a, offset_a = pd_a.to_ao
    probs_b, offset_b = pd_b.to_ao

    probs_a.each_with_index do |pa,i|
      probs_b.each_with_index do |pb,j|
        k = m_a * (i + offset_a) + m_b * (j + offset_b) - combined_min
        pc = pa * pb
        new_probs[ k ] += pc
      end
    end
    GamesDice::Probabilities.new( new_probs, combined_min )
  end

  private

  # Convert hash to array,offset notation
  def self.prob_h_to_ao h
    rmin,rmax = h.keys.minmax
    o = rmin
    a = Array.new( 1 + rmax - rmin, 0.0 )
    h.each { |k,v| a[k-rmin] = v }
    [a,o]
  end

  # Convert array,offset notation to hash
  def self.prob_ao_to_h a, o
    h = Hash.new
    a.each_with_index { |v,i| h[i+o] = v if v > 0.0 }
    h
  end

  def calc_expected
    total = 0.0
    @probs.each_with_index { |v,i| total += (i+@offset)*v }
    total
  end

end # class GamesDice::Probabilities
