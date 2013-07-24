# @!visibility private
module GamesDice::ProbabilityValidations

  def self.included(klass)
    klass.extend ClassMethods
  end

  private

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

  def check_keep_mode kmode
    raise "Keep mode #{kmode.inspect} not recognised" unless [:keep_best,:keep_worst].member?( kmode )
  end

  module ClassMethods
    private

    def check_is_gdp *probs
      probs.each do |prob|
        unless prob.is_a?( GamesDice::Probabilities )
          raise TypeError, "parameter is not a GamesDice::Probabilities"
        end
      end
    end
  end
end

# @!visibility private
# This module is a set of related private methods for GamesDice::Probabilities that
# calculate how two distributions can be combined.
module GamesDice::ProbabilityCalcAddDistributions
  private

  def calc_combined_extremes m_a, pd_a, m_b, pd_b
    [ [ :min, :min ], [ :min, :max ], [ :max, :min ], [ :max, :max ] ].map do |pda_meth, pdb_meth|
      m_a * pd_a.send(pda_meth) + m_b * pd_b.send(pdb_meth)
    end
  end

  def add_distributions_internal combined_min, combined_max, m_a, pd_a, m_b, pd_b
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
end


# @!visibility private
# This module is a set of related private methods for GamesDice::Probabilities that
# calculate how a distribution can be combined with itself.
module GamesDice::ProbabilityCalcSums

  private

  def repeat_sum_internal( n )
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

  def repeat_n_sum_k_internal( n, k, kmode )
    if k >= n
      return repeat_sum_internal( n )
    end
    new_probs = Array.new( @probs.count * k, 0.0 )
    new_offset = @offset * k
    d = n - k

    each do | q, p_maybe |
      repeat_n_sum_k_each_q( q, p_maybe, n, k, kmode, d, new_probs, new_offset )
    end

    GamesDice::Probabilities.new( new_probs, new_offset )
  end

  def repeat_n_sum_k_each_q q, p_maybe, n, k, kmode, d, new_probs, new_offset
    # keep_distributions is array of Probabilities, indexed by number of keepers > q, which is in 0...k
    keep_distributions = calc_keep_distributions( k, q, kmode )
    p_table = calc_p_table( q, p_maybe, kmode )
    (0...k).each do |kn|
      repeat_n_sum_k_each_q_kn( k, kn, d, new_probs, new_offset, keep_distributions, p_table )
    end
  end

  def repeat_n_sum_k_each_q_kn k, kn, d, new_probs, new_offset, keep_distributions, p_table
    keepers = [2] * kn + [1] * (k-kn)
    p_so_far = keepers.inject(1.0) { |p,idx| p * p_table[idx] }
    return unless p_so_far > 0.0
    (0..d).each do |dn|
      repeat_n_sum_k_each_q_kn_dn( keepers, kn, d, dn, p_so_far, new_probs, new_offset, keep_distributions, p_table )
    end
  end

  def repeat_n_sum_k_each_q_kn_dn keepers, kn, d, dn, p_so_far, new_probs, new_offset, keep_distributions, p_table
    discards = [1] * (d-dn) + [0] * dn
    sequence = keepers + discards
    p_sequence = discards.inject( p_so_far ) { |p,idx| p * p_table[idx] }
    return unless p_sequence > 0.0
    p_sequence *= GamesDice::Combinations.count_variations( sequence )
    kd = keep_distributions[kn]
    kd.each { |r,p_r| new_probs[r-new_offset] += p_r * p_sequence }
  end

  def calc_keep_distributions k, q, kmode
    kd_probabilities = calc_keep_definite_distributions q, kmode

    keep_distributions = [ GamesDice::Probabilities.new( [1.0], q * k ) ]
    if kd_probabilities && k > 1
      (1...k).each do |n|
        extra_o = GamesDice::Probabilities.new( [1.0], q * ( k - n ) )
        n_probs = kd_probabilities.repeat_sum( n )
        keep_distributions[n] = GamesDice::Probabilities.add_distributions( extra_o, n_probs )
      end
    end

    keep_distributions
  end

  def calc_keep_definite_distributions q, kmode
    kd_probabilities = nil
    case kmode
    when :keep_best
      p_definites = p_gt(q)
      kd_probabilities = given_ge( q + 1 ) if p_definites > 0.0
    when :keep_worst
      p_definites = p_lt(q)
      kd_probabilities = given_le( q - 1 ) if p_definites > 0.0
    end
    kd_probabilities
  end

  def calc_p_table q, p_maybe, kmode
    case kmode
    when :keep_best
      p_kept = p_gt(q)
      p_rejected = p_lt(q)
    when :keep_worst
      p_kept = p_lt(q)
      p_rejected = p_gt(q)
    end
    [ p_rejected, p_maybe, p_kept ]
  end

end


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
