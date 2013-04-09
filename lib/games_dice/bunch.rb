module GamesDice

  # models a set of identical dice, that can be "rolled" and combined into a simple integer result. The
  # dice are identical in number of sides, and any rolling rules that apply to them
  class Bunch
    # attributes is a hash of symbols used to set attributes of the new Bunch object. Each
    # attribute is explained in more detail in its own section. The following hash keys and values
    # are mandatory:
    #  :ndice
    #  :sides
    # The following are optional, and modify the behaviour of the Bunch object
    #  :name
    #  :prng
    #  :rerolls
    #  :maps
    #  :keep_mode
    #  :keep_number
    # Any other keys provided to the constructor are ignored
    def initialize( attributes )
      @name = attributes[:name].to_s
      @ndice = Integer(attributes[:ndice])
      raise ArgumentError, ":ndice must be 1 or more, but got #{@ndice}" unless @ndice > 0
      @sides = Integer(attributes[:sides])
      raise ArgumentError, ":sides must be 1 or more, but got #{@sides}" unless @sides > 0

      options = Hash.new

      if attributes[:prng]
        # We deliberately do not clone this object, it will often be intended that it is shared
        prng = attributes[:prng]
        raise ":prng does not support the rand() method" if ! prng.respond_to?(:rand)
      end

      needs_complex_die = false

      if attributes[:rerolls]
        needs_complex_die = true
        options[:rerolls] = attributes[:rerolls].clone
      end

      if attributes[:maps]
        needs_complex_die = true
        options[:maps] = attributes[:maps].clone
      end

      if needs_complex_die
        options[:prng] = prng
        @single_die = GamesDice::ComplexDie.new( @sides, options )
      else
        @single_die = GamesDice::Die.new( @sides, prng )
      end

      case attributes[:keep_mode]
      when nil then
        @keep_mode = nil
      when :keep_best then
        @keep_mode = :keep_best
        @keep_number = Integer(attributes[:keep_number] || 1)
      when :keep_worst then
        @keep_mode = :keep_worst
        @keep_number = Integer(attributes[:keep_number] || 1)
      else
        raise ArgumentError, ":keep_mode can be nil, :keep_best or :keep_worst. Got #{attributes[:keep_mode].inspect}"
      end
    end

    # the string name as provided to the constructor, it will appear in explain_result
    attr_reader :name

    # integer number of dice to roll (initially, before re-rolls etc)
    attr_reader :ndice

    # individual die that will be rolled, #ndice times, an GamesDice::Die or GamesDice::ComplexDie object.
    attr_reader :single_die

    # may be nil, :keep_best or :keep_worst
    attr_reader :keep_mode

    # number of "best" or "worst" results to select when #keep_mode is not nil. This attribute is
    # 1 by default if :keep_mode is supplied, or nil by default otherwise.
    attr_reader :keep_number

    # after calling #roll, this is set to the final integer value from using the dice as specified
    attr_reader :result

    # either nil, or an array of GamesDice::RerollRule objects that are assessed on each roll of #single_die
    # Reroll types :reroll_new_die and :reroll_new_keeper do not affect the #single_die, but are instead
    # assessed in this container object
    def rerolls
      @single_die.rerolls
    end

    # either nil, or an array of GamesDice::MapRule objects that are assessed on each result of #single_die (after rerolls are completed)
    def maps
      @single_die.rerolls
    end

    # after calling #roll, this is an array of GamesDice::DieResult objects, one from each #single_die rolled,
    # allowing inspection of how the result was obtained.
    def result_details
      return nil unless @raw_result_details
      @raw_result_details.map { |r| r.is_a?(Fixnum) ? GamesDice::DieResult.new(r) : r }
    end

    # minimum possible integer value
    def min
      n = @keep_mode ? [@keep_number,@ndice].min : @ndice
      return n * @single_die.min
    end

    # maximum possible integer value
    def max
      n = @keep_mode ? [@keep_number,@ndice].min : @ndice
      return n * @single_die.max
    end

    # returns a hash of value (Integer) => probability (Float) pairs. Warning: Some dice schemes
    # cause this method to take a long time, and use a lot of memory. The worst-case offenders are
    # dice schemes with a #keep_mode of :keep_best or :keep_worst.
    def probabilities
      return @probabilities if @probabilities
      @probabilities_complete = true

      # TODO: It is possible to optimise this slightly by combining already-calculated values
      # Adding dice is same as multiplying probability sets for that number of dice
      # Combine(probabililities_3_dice, probabililities_single_die) == Combine(probabililities_2_dice, probabililities_2_dice)
      # It is possible to minimise the total number of multiplications, gaining about 30% efficiency, with careful choices
      single_roll_probs = @single_die.probabilities
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

      @probabilities = combined_probs
      @probabilities_min, @probabilities_max = @probabilities.keys.minmax
      @prob_ge = {}
      @prob_le = {}
      @probabilities
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

    # returns mean expected value as a Float
    def expected_result
      @expected_result ||= probabilities.inject(0.0) { |accumulate,p| accumulate + p[0] * p[1] }
    end

    # simulate dice roll according to spec. Returns integer final total, and also stores it in #result
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
end # module GamesDice
