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

class GamesDice::Bunch
  # The constructor accepts parameters that are suitable for either GamesDice::Die or GamesDice::ComplexDie
  # and decides which of those classes to instantiate.
  # @param [Hash] options
  # @option options [Integer] :ndice Number of dice in the bunch, *mandatory*
  # @option options [Integer] :sides Number of sides on a single die in the bunch, *mandatory*
  # @option options [String] :name Optional name for the bunch
  # @option options [Array<GamesDice::RerollRule,Array>] :rerolls Optional rules that cause the die to roll again
  # @option options [Array<GamesDice::MapRule,Array>] :maps Optional rules to convert a value into a final result for the die
  # @option options [#rand] :prng Optional alternative source of randomness to Ruby's built-in #rand, passed to GamesDice::Die's constructor
  # @option options [Symbol] :keep_mode Optional, either *:keep_best* or *:keep_worst*
  # @option options [Integer] :keep_number Optional number of dice to keep when :keep_mode is not nil
  # @return [GamesDice::Bunch]
  def initialize( options )
    @name = options[:name].to_s
    @ndice = Integer(options[:ndice])
    raise ArgumentError, ":ndice must be 1 or more, but got #{@ndice}" unless @ndice > 0
    @sides = Integer(options[:sides])
    raise ArgumentError, ":sides must be 1 or more, but got #{@sides}" unless @sides > 0

    attr = Hash.new

    if options[:prng]
      # We deliberately do not clone this object, it will often be intended that it is shared
      prng = options[:prng]
      raise ":prng does not support the rand() method" if ! prng.respond_to?(:rand)
    end

    needs_complex_die = false

    if options[:rerolls]
      needs_complex_die = true
      attr[:rerolls] = options[:rerolls].clone
    end

    if options[:maps]
      needs_complex_die = true
      attr[:maps] = options[:maps].clone
    end

    if needs_complex_die
      attr[:prng] = prng
      @single_die = GamesDice::ComplexDie.new( @sides, attr )
    else
      @single_die = GamesDice::Die.new( @sides, prng )
    end

    case options[:keep_mode]
    when nil then
      @keep_mode = nil
    when :keep_best then
      @keep_mode = :keep_best
      @keep_number = Integer(options[:keep_number] || 1)
    when :keep_worst then
      @keep_mode = :keep_worst
      @keep_number = Integer(options[:keep_number] || 1)
    else
      raise ArgumentError, ":keep_mode can be nil, :keep_best or :keep_worst. Got #{options[:keep_mode].inspect}"
    end
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
  attr_reader :result

  # @!attribute [r] label
  # Description that will be used in explanations with more than one bunch
  # @return [String]
  def label
    return @name if @name != ''
    return @ndice.to_s + 'd' + @sides.to_s
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
    return nil unless @raw_result_details
    @raw_result_details.map { |r| r.is_a?(Fixnum) ? GamesDice::DieResult.new(r) : r }
  end

  # @!attribute [r] min
  # Minimum possible result from a call to #roll
  # @return [Integer]
  def min
    n = @keep_mode ? [@keep_number,@ndice].min : @ndice
    return n * @single_die.min
  end

  # @!attribute [r] max
  # Maximum possible result from a call to #roll
  # @return [Integer]
  def max
    n = @keep_mode ? [@keep_number,@ndice].min : @ndice
    return n * @single_die.max
  end

  # Calculates the probability distribution for the bunch. When the bunch is composed of dice with
  # open-ended re-roll rules, there are some arbitrary limits imposed to prevent large amounts of
  # recursion.
  # @return [GamesDice::Probabilities] Probability distribution of bunch.
  def probabilities
    return @probabilities if @probabilities
    @probabilities_complete = true

    # TODO: It is possible to optimise this slightly by combining already-calculated values
    # Adding dice is same as multiplying probability sets for that number of dice
    # Combine(probabililities_3_dice, probabililities_single_die) == Combine(probabililities_2_dice, probabililities_2_dice)
    # It is possible to minimise the total number of multiplications, gaining about 30% efficiency, with careful choices
    single_roll_probs = @single_die.probabilities.to_h
    if @keep_mode && @ndice > @keep_number
      preadd_probs = {}
      single_roll_probs.each { |k,v| preadd_probs[k.to_s] = v }

      (@keep_number-1).times do
        preadd_probs = prob_accumulate_combinations preadd_probs, single_roll_probs
      end
      extra_dice = @ndice - @keep_number
      extra_dice.times do
        preadd_probs = prob_accumulate_combinations preadd_probs, single_roll_probs, @keep_mode
      end
      combined_probs = {}
      preadd_probs.each do |k,v|
        total = k.split(';').map { |s| s.to_i }.inject(:+)
        combined_probs[total] ||= 0.0
        combined_probs[total] += v
      end
    else
      combined_probs = single_roll_probs.clone
      (@ndice-1).times do
        combined_probs = prob_accumulate combined_probs, single_roll_probs
      end
    end

    @probabilities_min, @probabilities_max = combined_probs.keys.minmax
    @probabilities = GamesDice::Probabilities.new( combined_probs )
  end

  # Simulates rolling the bunch of identical dice
  # @return [Integer] Sum of all rolled dice, or sum of all keepers
  def roll
    @result = 0
    @raw_result_details = []

    @ndice.times do
      @result += @single_die.roll
      @raw_result_details << @single_die.result
    end

    if ! @keep_mode
      return @result
    end

    use_dice = if @keep_mode && @keep_number < @ndice
      case @keep_mode
      when :keep_best then @raw_result_details.sort[-@keep_number..-1]
      when :keep_worst then @raw_result_details.sort[0..(@keep_number-1)]
      end
    else
      @raw_result_details
    end

    @result = use_dice.inject(0) { |so_far, die_result| so_far + die_result }
  end

  # @!attribute [r] explain_result
  # Explanation of result, or nil if no call to #roll yet.
  # @return [String,nil]
  def explain_result
    return nil unless @result

    explanation = ''

    # With #keep_mode, we may need to show unused and used dice separately
    used_dice = result_details
    unused_dice = []

    # Pick highest numbers and their associated details
    if @keep_mode && @keep_number < @ndice
      full_dice = result_details.sort_by { |die_result| die_result.total }
      case @keep_mode
      when :keep_best then
        used_dice = full_dice[-@keep_number..-1]
        unused_dice = full_dice[0..full_dice.length-1-@keep_number]
      when :keep_worst then
        used_dice = full_dice[0..(@keep_number-1)]
        unused_dice = full_dice[@keep_number..(full_dice.length-1)]
      end
    end

    # Show unused dice (if any)
    if @keep_mode || @single_die.maps
      explanation += result_details.map do |die_result|
        die_result.explain_value
      end.join(', ')
      if @keep_mode
        separator = @single_die.maps ? ', ' : ' + '
        explanation += ". Keep: " + used_dice.map do |die_result|
          die_result.explain_total
        end.join( separator )
      end
      if @single_die.maps
        explanation += ". Successes: #{@result}"
      end
      explanation += " = #{@result}" if @keep_mode && ! @single_die.maps && @keep_number > 1
    else
      explanation += used_dice.map do |die_result|
        die_result.explain_value
      end.join(' + ')
      explanation += " = #{@result}" if @ndice > 1
    end

    explanation
  end

  private

  # combines two sets of probabilities where the end result is the first set of keys plus
  # the second set of keys, at the associated probailities of the values
  def prob_accumulate first_probs, second_probs
    accumulator = Hash.new

    first_probs.each do |v1,p1|
      second_probs.each do |v2,p2|
        v3 = v1 + v2
        p3 = p1 * p2
        accumulator[v3] ||= 0.0
        accumulator[v3] += p3
      end
    end

    accumulator
  end

  # combines two sets of probabilities, as above, except tracking unique permutations
  def prob_accumulate_combinations so_far, die_probs, keep_rule = nil
    accumulator = Hash.new

    so_far.each do |sig,p1|
      combo = sig.split(';').map { |s| s.to_i }

      case keep_rule
      when nil then
        die_probs.each do |v2,p2|
          new_sig = (combo + [v2]).sort.join(';')
          p3 = p1 * p2
          accumulator[new_sig] ||= 0.0
          accumulator[new_sig] += p3
        end
      when :keep_best then
        need_more_than = combo.min
        die_probs.each do |v2,p2|
          if v2 > need_more_than
            new_sig = (combo + [v2]).sort[1..combo.size].join(';')
          else
            new_sig = sig
          end
          p3 = p1 * p2
          accumulator[new_sig] ||= 0.0
          accumulator[new_sig] += p3
        end
      when :keep_worst then
        need_less_than = combo.max
        die_probs.each do |v2,p2|
          if v2 < need_less_than
            new_sig = (combo + [v2]).sort[0..(combo.size-1)].join(';')
          else
            new_sig = sig
          end
          p3 = p1 * p2
          accumulator[new_sig] ||= 0.0
          accumulator[new_sig] += p3
        end
      end
    end

    accumulator
  end

  # Generates all sets of [throw_away,may_keep_exactly,keep_preferentially,combinations] that meet
  # criteria for correct total number of dice and keep dice. These then need to be assessed for every
  # die value by the caller to get a full set of probabilities
  def generate_item_counts total_dice, keep_dice
    # Constraints are:
    # may_keep_exactly must be at least 1, and at most is all the dice
    # keep_preferentially plus may_keep_exactly must be >= keep_dice, but keep_preferentially < keep dice
    # sum of all three always == total_dice
    item_counts = []
    (1..total_dice).each do |may_keep_exactly|
      min_kp = [keep_dice - may_keep_exactly, 0].max
      max_kp = [keep_dice - 1, total_dice - may_keep_exactly].min
      (min_kp..max_kp).each do |keep_preferentially|
        counts = [ total_dice - may_keep_exactly - keep_preferentially, may_keep_exactly, keep_preferentially ]
        counts << combinations(counts)
        item_counts << counts
      end
    end
    item_counts
  end

  # How many unique ways can a set of items, some of which are identical, be arranged?
  def combinations item_counts
    item_counts = item_counts.map { |i| Integer(i) }.select { |i| i > 0 }
    total_items = item_counts.inject(:+)
    numerator = 1.upto(total_items).inject(:*)
    denominator = item_counts.map { |i| 1.upto(i).inject(:*) }.inject(:*)
    numerator / denominator
  end

end # class Bunch
