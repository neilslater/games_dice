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
    @probs = check_probs_array probs.clone
    @offset = Integer(offset)
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
    @probs.each_with_index { |p,i| yield( i+@offset, p ) if p > 0.0 }
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

  # Probability distribution derived from this one, where we know (or are only interested in
  # situations where) the result is greater than or equal to target.
  # @param [Integer] target
  # @return [GamesDice::Probabilities] new distribution.
  def given_ge target
    target = Integer(target)
    target = min if min > target
    p = p_ge(target)
    raise "There is no valid distribution given a result >= #{target}" unless p > 0.0
    mult = 1.0/p
    new_probs = @probs[target-@offset,@probs.count-1].map { |x| x * mult }
    GamesDice::Probabilities.new( new_probs, target )
  end

  # Probability distribution derived from this one, where we know (or are only interested in
  # situations where) the result is less than or equal to target.
  # @param [Integer] target
  # @return [GamesDice::Probabilities] new distribution.
  def given_le target
    target = Integer(target)
    target = max if max < target
    p = p_le(target)
    raise "There is no valid distribution given a result <= #{target}" unless p > 0.0
    mult = 1.0/p
    new_probs = @probs[0..target-@offset].map { |x| x * mult }
    GamesDice::Probabilities.new( new_probs, @offset )
  end

  # Creates new instance of GamesDice::Probabilities.
  # @param [Hash] prob_hash A hash representation of the distribution, each key is an integer result,
  #   and the matching value is probability of getting that result
  # @return [GamesDice::Probabilities]
  def self.from_h prob_hash
    raise TypeError, "from_h expected a Hash" unless prob_hash.is_a? Hash
    probs, offset = prob_h_to_ao( prob_hash )
    GamesDice::Probabilities.new( probs, offset )
  end

  # Distribution for a die with equal chance of rolling 1..N
  # @param [Integer] sides Number of sides on die
  # @return [GamesDice::Probabilities]
  def self.for_fair_die sides
    sides = Integer(sides)
    raise ArgumentError, "sides must be at least 1" unless sides > 0
    raise ArgumentError, "sides can be at most 100000" if sides > 100000
    GamesDice::Probabilities.new( Array.new( sides, 1.0/sides ), 1 )
  end

  # Combines two distributions to create a third, that represents the distribution created when adding
  # results together.
  # @param [GamesDice::Probabilities] pd_a First distribution
  # @param [GamesDice::Probabilities] pd_b Second distribution
  # @return [GamesDice::Probabilities]
  def self.add_distributions pd_a, pd_b
    unless pd_a.is_a?( GamesDice::Probabilities ) && pd_b.is_a?( GamesDice::Probabilities )
      raise TypeError, "parameter to add_distributions is not a GamesDice::Probabilities"
    end

    combined_min = pd_a.min + pd_b.min
    combined_max = pd_a.max + pd_b.max

    add_distributions_internal combined_min, combined_max, 1, pd_a, 1, pd_b
  end

  # Combines two distributions with multipliers to create a third, that represents the distribution
  # created when adding weighted results together.
  # @param [Integer] m_a Weighting for first distribution
  # @param [GamesDice::Probabilities] pd_a First distribution
  # @param [Integer] m_b Weighting for second distribution
  # @param [GamesDice::Probabilities] pd_b Second distribution
  # @return [GamesDice::Probabilities]
  def self.add_distributions_mult m_a, pd_a, m_b, pd_b
    unless pd_a.is_a?( GamesDice::Probabilities ) && pd_b.is_a?( GamesDice::Probabilities )
      raise TypeError, "parameter to add_distributions_mult is not a GamesDice::Probabilities"
    end

    m_a = Integer(m_a)
    m_b = Integer(m_b)

    combined_min, combined_max = [
      m_a * pd_a.min + m_b * pd_b.min, m_a * pd_a.max + m_b * pd_b.min,
      m_a * pd_a.min + m_b * pd_b.max, m_a * pd_a.max + m_b * pd_b.max,
      ].minmax

    add_distributions_internal combined_min, combined_max, m_a, pd_a, m_b, pd_b
  end

  # Returns a symbol for the language name that this class is implemented in. The C version of the
  # code is noticeably faster when dealing with larger numbers of possible results.
  # @return [Symbol] Either :c or :ruby
  def self.implemented_in
    :ruby
  end

  # Adds a distribution to itself repeatedly, to simulate a number of dice
  # results being summed.
  # @param [Integer] n Number of repetitions, must be at least 1
  # @return [GamesDice::Probabilities] new distribution
  def repeat_sum n
    n = Integer( n )
    raise "Cannot combine probabilities less than once" if n < 1
    raise "Probability distribution too large" if ( n * @probs.count ) > 1000000
    pd_power = self
    pd_result = nil

    use_power = 1
    loop do
      if ( use_power & n ) > 0
        if pd_result
          pd_result = GamesDice::Probabilities.add_distributions( pd_result, pd_power )
        else
          pd_result = pd_power
        end
      end
      use_power = use_power << 1
      break if use_power > n
      pd_power = GamesDice::Probabilities.add_distributions( pd_power, pd_power )
    end
    pd_result
  end

  # Calculates distribution generated by summing best k results of n iterations
  # of the distribution.
  # @param [Integer] n Number of repetitions, must be at least 1
  # @param [Integer] k Number of best results to keep and sum
  # @return [GamesDice::Probabilities] new distribution
  def repeat_n_sum_k n, k, kmode = :keep_best
    n = Integer( n )
    k = Integer( k )
    raise "Cannot combine probabilities less than once" if n < 1
    # Technically this is a limitation of C code, but Ruby version is most likely slow and inaccurate beyond 170
    raise "Too many dice to calculate numbers of arrangements" if n > 170
    if k >= n
      return repeat_sum( n )
    end
    new_probs = Array.new( @probs.count * k, 0.0 )
    new_offset = @offset * k
    d = n - k

    each do | q, p_maybe |
      next unless p_maybe > 0.0

      # keep_distributions is array of Probabilities, indexed by number of keepers > q, which is in 0...k
      keep_distributions = calc_keep_distributions( k, q, kmode )
      p_table = calc_p_table( q, p_maybe, kmode )

      (0...k).each do |n|
        keepers = [2] * n + [1] * (k-n)
        p_so_far = keepers.inject(1.0) { |p,idx| p * p_table[idx] }
        next unless p_so_far > 0.0
        (0..d).each do |dn|
          discards = [1] * (d-dn) + [0] * dn
          sequence = keepers + discards
          p_sequence = discards.inject( p_so_far ) { |p,idx| p * p_table[idx] }
          next unless p_sequence > 0.0
          p_sequence *= GamesDice::Combinations.count_variations( sequence )
          kd = keep_distributions[n]
          kd.each { |r,p_r| new_probs[r-new_offset] += p_r * p_sequence }
        end
      end
    end
    GamesDice::Probabilities.new( new_probs, new_offset )
  end

  private

  def self.add_distributions_internal combined_min, combined_max, m_a, pd_a, m_b, pd_b
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

  def check_probs_array probs_array
    raise TypeError unless probs_array.is_a?( Array )
    probs_array.map!{ |n| Float(n) }
    total = probs_array.inject(0.0) do |t,x|
      if x < 0.0 || x > 1.0
        raise ArgumentError, "Found probability value #{x} which is not in range 0.0..1.0"
      end
      t+x
    end
    if (total-1.0).abs > 1e-6
      raise ArgumentError, "Total probabilities too far from 1.0 for a valid distribution"
    end
    probs_array
  end

  def calc_keep_distributions k, q, kmode
    if kmode == :keep_best
      p_definites = p_gt(q)
      kd_probabilities = given_ge( q + 1 ) if p_definites > 0.0
    elsif kmode == :keep_worst
      p_definites = p_lt(q)
      kd_probabilities = given_le( q - 1 ) if p_definites > 0.0
    else
      raise "Keep mode #{kmode.inspect} not recognised"
    end

    keep_distributions = [ GamesDice::Probabilities.new( [1.0], q * k ) ]
    if p_definites > 0.0 && k > 1
      (1...k).each do |n|
        extra_o = GamesDice::Probabilities.new( [1.0], q * ( k - n ) )
        n_probs = kd_probabilities.repeat_sum( n )
        keep_distributions[n] = GamesDice::Probabilities.add_distributions( extra_o, n_probs )
      end
    end

    keep_distributions
  end

  def calc_p_table q, p_maybe, kmode
    if kmode == :keep_best
      p_kept = p_gt(q)
      p_rejected = p_lt(q)
    elsif kmode == :keep_worst
      p_kept = p_lt(q)
      p_rejected = p_gt(q)
    else
      raise "Keep mode #{kmode.inspect} not recognised"
    end
    [ p_rejected, p_maybe, p_kept ]
  end

  # Convert hash to array,offset notation
  def self.prob_h_to_ao h
    rmin,rmax = h.keys.minmax
    o = rmin
    s = 1 + rmax - rmin
    raise ArgumentError, "Range of possible results too large" if s > 1000000
    a = Array.new( s, 0.0 )
    h.each { |k,v| a[k-rmin] = Float(v) }
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

# @!visibility private
# Helper module with optimised Ruby for counting variations of arrays, such as those returned by
# Array#repeated_combination
#
# @example How many ways can [3,3,6] be arranged?
#  GamesDice::Combinations.count_variations( [3,3,6] )
#  => 3
#
# @example When prob( a ) and result( a ) are same for any arrangement of Array a
#  items = [1,2,3,4,5,6]
#  items.repeated_combination(5).each do |a|
#    this_result = result( a )
#    this_prob = prob( a ) * GamesDice::Combinations.count_variations( a )
#    # Do something useful with this knowledge! E.g. save it to probability array.
#  end
#
module GamesDice::Combinations
  @@variations_cache = {}
  @@factorial_cache = [1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880, 3628800]

  # Counts variations of an array. A unique variation is an arrangement of the array elements which
  # is detectably different (using ==) from any other. So [1,1,1] has only 1 unique arrangement,
  # but [1,2,3] has 6 possibilities.
  # @param [Array] array List of things that can be arranged
  # @return [Integer] Number of unique arrangements
  def self.count_variations array
    all_count = array.count
    group_sizes = group_counts( array )
    cache_key = all_count.to_s + ":" + group_sizes.join(',')
    @@variations_cache[cache_key] ||= variations_of( all_count, group_sizes )
  end

  private

  def self.variations_of all_count, groups
    all_arrangements = factorial( all_count )
    # The reject is an optimisation to avoid calculating and multplying by factorial(1) (==1)
    identical_arrangements = groups.reject {|x| x==1 }.inject(1) { |prod,g| prod * factorial(g) }
    all_arrangements/identical_arrangements
  end

  # Returns counts of unique items in array e.g. [8,8,8,7,6,6] returns [1,2,3]
  # Sort is for caching
  def self.group_counts array
    array.group_by {|x| x}.values.map {|v| v.count}.sort
  end

  def self.factorial n
    # Can start range from 2 because we have pre-cached the result for n=1
    @@factorial_cache[n] ||= (2..n).inject(:*)
  end
end
