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
  # @return [Boolean, nil] Depending on completeness when generating #probabilites
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

  # @!attribute [r] min
  # @return [Integer] Minimum possible result from a call to #roll
  def min
    return @min_result if @min_result
    @min_result, @max_result = [probabilities.min, probabilities.max]
    return @min_result if @probabilities_complete
    logical_min, logical_max = logical_minmax
    @min_result, @max_result = [@min_result, @max_result, logical_min, logical_max].minmax
    @min_result
  end

  # @!attribute [r] max
  # @return [Integer] Maximum possible result from a call to #roll
  def max
    return @max_result if @max_result
    @min_result, @max_result = [probabilities.min, probabilities.max]
    return @max_result if @probabilities_complete
    logical_min, logical_max = logical_minmax
    @min_result, @max_result = [@min_result, @max_result, logical_min, logical_max].minmax
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
      probs = @basic_die.probabilities.to_h
      prob_hash = {}
      probs.each do |v,p|
        m, n = calc_maps(v)
        prob_hash[m] ||= 0.0
        prob_hash[m] += p
      end
    else
      prob_hash = @basic_die.probabilities.to_h
    end
    @prob_ge = {}
    @prob_le = {}
    @probabilities = GamesDice::Probabilities.new( prob_hash )
  end

  # Simulates rolling the die
  # @param [Symbol] reason Assign a reason for rolling the first die.
  # @return [GamesDice::DieResult] Detailed results from rolling the die, including resolution of rules.
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

  def construct_rerolls rerolls_input
    return nil unless rerolls_input
    raise TypeError, "rerolls should be an Array, instead got #{rerolls_input.inspect}" unless rerolls_input.is_a?(Array)
    rerolls_input.map do |reroll_item|
      case reroll_item
      when Array then GamesDice::RerollRule.new( reroll_item[0], reroll_item[1], reroll_item[2], reroll_item[3] )
      when GamesDice::RerollRule then reroll_item
      else
        raise TypeError, "items in rerolls should be GamesDice::RerollRule or Array, instead got #{reroll_item.inspect}"
      end
    end
  end

  def construct_maps maps_input
    return nil unless maps_input
    raise TypeError, "maps should be an Array, instead got #{maps_input.inspect}" unless maps_input.is_a?(Array)
    maps_input.map do |map_item|
      case map_item
      when Array then GamesDice::MapRule.new( map_item[0], map_item[1], map_item[2], map_item[3] )
      when GamesDice::MapRule then map_item
      else
        raise TypeError, "items in maps should be GamesDice::MapRule or Array, instead got #{map_item.inspect}"
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
