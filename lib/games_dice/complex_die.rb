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

class GamesDice::ComplexDie

  # @!visibility private
  # arbitrary limit to speed up probability calculations. It should
  # be larger than anything seen in real-world tabletop games.
  MAX_REROLLS = 1000

  # Creates new instance of GamesDice::ComplexDie
  # @param [Integer] sides Number of sides on a single die, passed to GamesDice::Die's constructor
  # @param [Hash] options
  # @option options [Array<GamesDice::RerollRule,Array>] :rerolls The rules that cause the die to roll again
  # @option options [Array<GamesDice::MapRule,Array>] :maps The rules to convert a value into a final result for the die
  # @option options [#rand] :prng An alternative source of randomness to Ruby's built-in #rand, passed to GamesDice::Die's constructor
  # @return [GamesDice::ComplexDie]
  def initialize( sides, options = {} )
    @basic_die = GamesDice::Die.new(sides, options[:prng])

    @rerolls = construct_rerolls( options[:rerolls] )
    @maps = construct_maps( options[:maps] )

    @total = nil
    @result = nil
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
    return @probabilities if @probabilities
    @probabilities_complete = true
    if @rerolls && @maps
      reroll_probs = recursive_probabilities
      prob_hash = {}
      reroll_probs.each do |v,p|
        m, n = calc_maps(v)
        prob_hash[m] ||= 0.0
        prob_hash[m] += p
      end
    elsif @rerolls
      prob_hash = recursive_probabilities
    elsif @maps
      prob_hash = {}
      @basic_die.probabilities.each do |v,p|
        m, n = calc_maps(v)
        prob_hash[m] ||= 0.0
        prob_hash[m] += p
      end
    else
      @probabilities = @basic_die.probabilities
      return @probabilities
    end
    @probabilities = GamesDice::Probabilities.from_h( prob_hash )
  end

  # Simulates rolling the die
  # @param [Symbol] reason Assign a reason for rolling the first die.
  # @return [GamesDice::DieResult] Detailed results from rolling the die, including resolution of rules.
  def roll( reason = :basic )
    @result = GamesDice::DieResult.new( @basic_die.roll, reason )
    roll_apply_rerolls
    roll_apply_maps
    @result
  end

  private

  def roll_apply_rerolls
    return unless @rerolls
    subtracting = false
    rerolls_remaining = @rerolls.map { |rule| rule.limit }

    loop do
      rule_idx = find_matching_reroll_rule( @basic_die.result, @result.rolls.length ,rerolls_remaining )
      break unless rule_idx

      rule = @rerolls[ rule_idx ]
      rerolls_remaining[ rule_idx ] -= 1
      subtracting = true if rule.type == :reroll_subtract

      # Apply the rule (note reversal for additions, after a subtract)
      if subtracting && rule.type == :reroll_add
        @result.add_roll( @basic_die.roll, :reroll_subtract )
      else
        @result.add_roll( @basic_die.roll, rule.type )
      end
    end
  end

  # Find which rule, if any, is being triggered
  def find_matching_reroll_rule check_value, num_rolls, rerolls_remaining
    @rerolls.zip(rerolls_remaining).find_index do |rule,remaining|
      next if rule.type == :reroll_subtract && num_rolls > 1
      remaining > 0 && rule.applies?( check_value )
    end
  end

  def roll_apply_maps
    return unless @maps
    m, n = calc_maps(@result.value)
    @result.apply_map( m, n )
  end

  def calc_minmax
    @min_result, @max_result = [probabilities.min, probabilities.max]
    return if @probabilities_complete
    logical_min, logical_max = logical_minmax
    @min_result, @max_result = [@min_result, @max_result, logical_min, logical_max].minmax
  end

  def construct_rerolls rerolls_input
    check_and_construct rerolls_input, GamesDice::RerollRule, 'rerolls'
  end

  def construct_maps maps_input
    check_and_construct maps_input, GamesDice::MapRule, 'maps'
  end

  def check_and_construct input, klass, label
    return nil unless input
    raise TypeError, "#{label} should be an Array, instead got #{input.inspect}" unless input.is_a?(Array)
    input.map do |i|
      case i
      when Array then klass.new( *i )
      when klass then i
      else
        raise TypeError, "items in #{label} should be #{klass.name} or Array, instead got #{i.inspect}"
      end
    end
  end

  def calc_maps x
    y, n = 0, ''
    @maps.find do |rule|
      maybe_y = rule.map_from( x )
      if maybe_y
        y = maybe_y
        n = rule.mapped_name
      end
      maybe_y
    end
    [y, n]
  end

  def minmax_mappings possible_values
    possible_values.map { |x| m, n = calc_maps( x ); m }.minmax
  end

  # This isn't 100% accurate, but does cover most "normal" scenarios, and we're only falling back to it when we have to
  def logical_minmax
    return [@basic_die.min,@basic_die.max] unless @rerolls || @maps
    return minmax_mappings( @basic_die.all_values ) unless @rerolls
    min_result, max_result = logical_rerolls_minmax
    return minmax_mappings( (min_result..max_result) ) if @maps
    return [min_result,max_result]
  end

  def logical_rerolls_minmax
    min_result = @basic_die.min
    max_result = @basic_die.max
    min_subtract, max_add = find_add_subtract_extremes
    if min_subtract
      min_result = [ min_subtract - max_add, min_subtract - max_result ].min
    end
    [ min_result, max_add + max_result ]
  end

  def find_add_subtract_extremes
    min_subtract = nil
    total_add = 0
    @rerolls.select {|r| [:reroll_add, :reroll_subtract].member?( r.type ) }.each do |rule|
      min_reroll,max_reroll = @basic_die.all_values.select { |v| rule.applies?( v ) }.minmax
      next unless min_reroll
      if rule.type == :reroll_subtract
        min_subtract = min_reroll if min_subtract.nil?
        min_subtract = min_reroll if min_subtract > min_reroll
      else
        total_add += max_reroll * rule.limit
      end
    end
    [ min_subtract, total_add ]
  end

  def recursive_probabilities probabilities={},prior_probability=1.0,depth=0,prior_result=nil,rerolls_left=nil,roll_reason=:basic,subtracting=false
    each_probability = prior_probability / @basic_die.sides
    depth += 1
    if depth >= 20 || each_probability < 1.0e-16
      @probabilities_complete = false
      stop_recursing = true
    end

    @basic_die.each_value do |v|
      recurse_probs_for_value( v, roll_reason, probabilities, each_probability, depth, prior_result, rerolls_left, subtracting, stop_recursing )
    end
    probabilities
  end

  def recurse_probs_for_value v, roll_reason, probabilities, each_probability, depth, prior_result, rerolls_left, subtracting, stop_recursing
    # calculate value, recurse if there is a reroll
    result_so_far, rerolls_remaining = calc_result_so_far(prior_result, rerolls_left, v, roll_reason )

    # Find which rule, if any, is being triggered
    rule_idx = find_matching_reroll_rule( v, result_so_far.rolls.length, rerolls_remaining )

    if rule_idx && ! stop_recursing
      recurse_probs_with_rule( probabilities, each_probability, depth, result_so_far, rerolls_remaining, rule_idx, subtracting )
    else
      t = result_so_far.total
      probabilities[ t ] ||= 0.0
      probabilities[ t ] += each_probability
    end
  end

  def recurse_probs_with_rule probabilities, each_probability, depth, result_so_far, rerolls_remaining, rule_idx, subtracting
    rule = @rerolls[ rule_idx ]
    rerolls_remaining[ rule_idx ] -= 1
    is_subtracting = true if subtracting || rule.type == :reroll_subtract

    # Apply the rule (note reversal for additions, after a subtract)
    if subtracting && rule.type == :reroll_add
      recursive_probabilities probabilities, each_probability, depth, result_so_far, rerolls_remaining, :reroll_subtract, is_subtracting
    else
      recursive_probabilities probabilities, each_probability, depth, result_so_far, rerolls_remaining, rule.type, is_subtracting
    end
  end

  def calc_result_so_far prior_result, rerolls_left, v, roll_reason
    if prior_result
      result_so_far = prior_result.clone
      result_so_far.add_roll(v,roll_reason)
      rerolls_remaining = rerolls_left.clone
    else
      result_so_far = GamesDice::DieResult.new(v,roll_reason)
      rerolls_remaining = @rerolls.map { |rule| rule.limit }
    end
    [result_so_far, rerolls_remaining]
  end

end # class ComplexDie
