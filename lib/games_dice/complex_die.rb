# complex die that rolls 1..N, and may re-roll and adjust final value based on
# parameters it is instantiated with
#  d = GamesDice::DieExploding.new( 6, :explode_up => true ) # 'exploding' die
#  d.roll # => GamesDice::DieResult of rolling die
#  d.result # => same GamesDice::DieResult as returned by d.roll
class GamesDice::ComplexDie

  # arbitrary limit to simplify calculations and stay in Integer range for convenience. It should
  # be much larger than anything seen in real-world tabletop games.
  MAX_REROLLS = 1000

  # sides is e.g. 6 for traditional cubic die, or 20 for icosahedron.
  # It can take non-traditional values, such as 7, but must be at least 1.
  #
  # options_hash may contain keys setting following attributes
  #  :rerolls => an array of rules that cause the die to roll again, see #rerolls
  #  :maps => an array of rules to convert a value into a final result for the die, see #maps
  #  :prng => any object that has a rand(x) method, which will be used instead of internal rand()
  def initialize(sides, options_hash = {})
    @basic_die = GamesDice::Die.new(sides, options_hash[:prng])

    @rerolls = options_hash[:rerolls]
    validate_rerolls
    @maps = options_hash[:maps]
    validate_maps

    @total = nil
    @result = nil
  end

  # underlying GamesDice::Die object, used to generate all individual rolls
  attr_reader :basic_die

  # may be nil, in which case no re-rolls are triggered, or an array of GamesDice::RerollRule objects
  attr_reader :rerolls

  # may be nil, in which case no mappings apply, or an array of GamesDice::MapRule objects
  attr_reader :maps

  # result of last call to #roll, nil if no call made yet
  attr_reader :result

  # true if probability calculation did not hit any limitations, so has covered all possible scenarios
  # false if calculation was cut short and probabilities are an approximation
  # nil if probabilities have not been calculated yet
  attr_reader :probabilities_complete

  # number of sides, same as #basic_die.sides
  def sides
    @basic_die.sides
  end

  # string explanation of roll, including any re-rolls etc, same as #result.explain_value
  def explain_result
    @result.explain_value
  end

  # minimum possible value
  def min
    return @min_result if @min_result
    @min_result, @max_result = probabilities.keys.minmax
    return @min_result if @probabilities_complete
    logical_min, logical_max = logical_minmax
    @min_result, @max_result = [@min_result, @max_result, logical_min, logical_max].minmax
    @min_result
  end

  # maximum possible value. A ComplexDie with open-ended additive re-rolls will calculate roughly 1001 times the
  # maximum of #basic_die.max (although the true value is infinite)
  def max
    return @max_result if @max_result
    @min_result, @max_result = probabilities.keys.minmax
    return @max_result if @probabilities_complete
    logical_min, logical_max = logical_minmax
    @min_result, @max_result = [@min_result, @max_result, logical_min, logical_max].minmax
    @max_result
  end

  # returns a hash of value (Integer) => probability (Float) pairs. For efficiency with re-rolls, the calculation may cut
  # short based on depth of recursion or closeness to total 1.0 probability. Therefore low probabilities
  # (less than one in a billion) in open-ended re-rolls are not always represented in the hash.
  def probabilities
    return @probabilities if @probabilities
    @probabilities_complete = true
    if @rerolls && @maps
      reroll_probs = recursive_probabilities
      @probabilities = {}
      reroll_probs.each do |v,p|
        m, n = calc_maps(v)
        @probabilities[m] ||= 0.0
        @probabilities[m] += p
      end
    elsif @rerolls
      @probabilities = recursive_probabilities
    elsif @maps
      probs = @basic_die.probabilities
      @probabilities = {}
      probs.each do |v,p|
        m, n = calc_maps(v)
        @probabilities[m] ||= 0.0
        @probabilities[m] += p
      end
    else
      @probabilities = @basic_die.probabilities
    end
    @probabilities_min, @probabilities_max = @probabilities.keys.minmax
    @prob_ge = {}
    @prob_le = {}
    @probabilities
  end

  # returns mean expected value as a Float
  def expected_result
    @expected_result ||= probabilities.inject(0.0) { |accumulate,p| accumulate + p[0] * p[1] }
  end

  # returns probability than a roll will produce a number greater than target integer
  def probability_gt target
    probability_ge( Integer(target) + 1 )
  end

  # returns probability than a roll will produce a number greater than or equal to target integer
  def probability_ge target
    target = Integer(target)
    return @prob_ge[target] if @prob_ge && @prob_ge[target]

    # Force caching if not already done
    probabilities
    return 1.0 if target <= @probabilities_min
    return 0.0 if target > @probabilities_max
    @prob_ge[target] = probabilities.select {|k,v| target <= k}.inject(0.0) {|so_far,pv| so_far + pv[1] }
  end

  # returns probability than a roll will produce a number less than or equal to target integer
  def probability_le target
    target = Integer(target)
    return @prob_le[target] if @prob_le && @prob_le[target]

    # Force caching of probability table if not already done
    probabilities
    return 1.0 if target >= @probabilities_max
    return 0.0 if target < @probabilities_min
    @prob_le[target] = probabilities.select {|k,v| target >= k}.inject(0.0) {|so_far,pv| so_far + pv[1] }
  end

  # returns probability than a roll will produce a number less than target integer
  def probability_lt target
    probability_le( Integer(target) - 1 )
  end

  # generates Integer between #min and #max, using rand()
  # first roll reason can be over-ridden, required for re-roll types that spawn new dice
  def roll( reason = :basic )
    # Important bit - actually roll the die
    @result = GamesDice::DieResult.new( @basic_die.roll, reason )

    if @rerolls
      subtracting = false
      rerolls_remaining = @rerolls.map { |rule| rule.limit }
      loop do
        # Find which rule, if any, is being triggered
        rule_idx = @rerolls.zip(rerolls_remaining).find_index do |rule,remaining|
          next if rule.type == :reroll_subtract && @result.rolls.length > 1
          remaining > 0 && rule.applies?( @basic_die.result )
        end
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

    # apply any mapping
    if @maps
      m, n = calc_maps(@result.value)
      @result.apply_map( m, n )
    end

    @result
  end

  private

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

  def validate_rerolls
    return unless @rerolls
    raise TypeError, "rerolls should be an Array, instead got #{@rerolls.inspect}" unless @rerolls.is_a?(Array)
    @rerolls.each do |rule|
      raise TypeError, "items in rerolls should be GamesDice::RerollRule, instead got #{rule.inspect}" unless rule.is_a?(GamesDice::RerollRule)
    end
  end

  def validate_maps
    return unless @maps
    raise TypeError, "maps should be an Array, instead got #{@maps.inspect}" unless @maps.is_a?(Array)
    @maps.each do |rule|
      raise TypeError, "items in maps should be GamesDice::MapRule, instead got #{rule.inspect}" unless rule.is_a?(GamesDice::MapRule)
    end
  end

  def minmax_mappings possible_values
    possible_values.map { |x| m, n = calc_maps( x ); m }.minmax
  end

  # This isn't 100% accurate, but does cover most "normal" scenarios, and we're only falling back to it when we have to
  def logical_minmax
    min_result = 1
    max_result = @basic_die.sides
    return [min_result,max_result] unless @rerolls || @maps
    return minmax_mappings( (min_result..max_result) ) unless @rerolls
    can_subtract = false
    @rerolls.each do |rule|
      next unless rule.type == :reroll_add || rule.type == :reroll_subtract
      min_reroll,max_reroll = (1..@basic_die.sides).select { |v| rule.applies?( v ) }.minmax
      next unless min_reroll && max_reroll
      if rule.type == :reroll_subtract
        can_subtract=true
        min_result = min_reroll - @basic_die.sides
      else
        max_result += max_reroll * rule.limit
      end
    end
    if can_subtract
      min_result -= max_result + @basic_die.sides
    end
    return minmax_mappings( (min_result..max_result) ) if @maps
    return [min_result,max_result]
  end

  def recursive_probabilities probabilities={},prior_probability=1.0,depth=0,prior_result=nil,rerolls_left=nil,roll_reason=:basic,subtracting=false
    each_probability = prior_probability / @basic_die.sides
    depth += 1
    if depth >= 20 || each_probability < 1.0e-12
      @probabilities_complete = false
      stop_recursing = true
    end

    (1..@basic_die.sides).each do |v|
      # calculate value, recurse if there is a reroll
      result_so_far = prior_result ? prior_result.clone : GamesDice::DieResult.new(v,roll_reason)
      result_so_far.add_roll(v,roll_reason) if prior_result
      rerolls_remaining = rerolls_left ? rerolls_left.clone : @rerolls.map { |rule| rule.limit }

      # Find which rule, if any, is being triggered
      rule_idx = @rerolls.zip(rerolls_remaining).find_index do |rule,remaining|
        next if rule.type == :reroll_subtract && result_so_far.rolls.length > 1
        remaining > 0 && rule.applies?( v )
      end

      if rule_idx && ! stop_recursing
        rule = @rerolls[ rule_idx ]
        rerolls_remaining[ rule_idx ] -= 1
        is_subtracting = true if subtracting || rule.type == :reroll_subtract

        # Apply the rule (note reversal for additions, after a subtract)
        if subtracting && rule.type == :reroll_add
          recursive_probabilities probabilities,each_probability,depth,result_so_far,rerolls_remaining,:reroll_subtract,is_subtracting
        else
          recursive_probabilities probabilities,each_probability,depth,result_so_far,rerolls_remaining,rule.type,is_subtracting
        end
      # just accumulate value on a regular roll
      else
        t = result_so_far.total
        probabilities[ t ] ||= 0.0
        probabilities[ t ] += each_probability
      end

    end
    probabilities.clone
  end

end # class ComplexDie
