# frozen_string_literal: true

module GamesDice
  class ComplexDie
    # @!visibility private
    # Private cache handling for bounded probability calculations.
    module ProbabilityHelpers
      private

      def probabilities_for_budget(limit)
        refresh_recipe
        return cached_probabilities if valid_probability_cache?(limit)

        with_recipe do
          cache_calculation(ProbabilityCalculation.new(self, limit))
        end
      rescue StandardError
        @probabilities_complete = nil
        raise
      end

      def cached_probabilities
        @probabilities_complete = @probability_error.zero?
        @probabilities
      end

      def cache_calculation(calculation)
        distribution = calculation.calculate
        @probability_error = calculation.error
        @probabilities_complete = @probability_error.zero?
        @probabilities = distribution
      end
    end

    # @!visibility private
    # Private extension methods for GamesDice::ComplexDie simulating rolls
    module RollHelpers
      private

      def roll_apply_rerolls(rules)
        return unless rules

        subtracting = false
        rerolls_remaining = rules.map(&:limit)

        rerolls_loop(subtracting, rerolls_remaining, rules)
      end

      def rerolls_loop(subtracting, rerolls_remaining, rules)
        loop do
          rule_idx = find_matching_reroll_rule(@basic_die.result, @result.rolls.length, rerolls_remaining, nil, rules)
          break unless rule_idx

          rule = rules[rule_idx]
          rerolls_remaining[rule_idx] -= 1
          subtracting = true if rule.type == :reroll_subtract
          roll_apply_reroll_rule rule, subtracting
        end
      end

      def roll_apply_reroll_rule(rule, is_subtracting)
        # Apply the rule (note reversal for additions, after a subtract)
        if is_subtracting && rule.type == :reroll_add
          @result.add_roll(@basic_die.roll, :reroll_subtract)
        else
          @result.add_roll(@basic_die.roll, rule.type)
        end
      end

      # Find which rule, if any, is being triggered
      def find_matching_reroll_rule(check_value, num_rolls, rerolls_remaining, budget = nil, rules = @rerolls)
        return unless rules

        rules.each_with_index do |rule, index|
          next unless available_reroll?(rule, num_rolls, rerolls_remaining[index])

          budget&.predicate
          return index if rule.applies?(check_value)
        end
        nil
      end

      def available_reroll?(rule, num_rolls, remaining)
        remaining.positive? && !(rule.type == :reroll_subtract && num_rolls > 1)
      end

      def roll_apply_maps(maps)
        return unless maps

        m, n = calc_maps(@result.value, nil, maps)
        @result.apply_map(m, n.dup)
      end

      def calc_maps(original_value, budget = nil, maps = @maps)
        maps.each do |rule|
          budget&.predicate
          mapped = rule.map_from(original_value)
          return [mapped, rule.mapped_name] if mapped
        end
        [0, '']
      end
    end

    # @!visibility private
    # Private extension methods for GamesDice::ComplexDie calculating min and max (which is surprisingly complex)
    module MinMaxHelpers
      private

      def calc_minmax
        cheap = cheap_minmax
        if cheap
          @min_result, @max_result = cheap
        else
          calculate_minmax
        end
      end

      def calculate_minmax
        distribution = probabilities
        if @probabilities_complete
          @min_result = distribution.min
          @max_result = distribution.max
        else
          @min_result, @max_result = logical_minmax
        end
      rescue ProbabilityLimitError
        @min_result, @max_result = safe_minmax
      end

      def cheap_minmax
        return if @maps
        return [1, sides] if !@rerolls || @rerolls.empty?
        return unless @rerolls.one?

        rule = @rerolls.first
        return unless rule.instance_of?(RerollRule) && ProbabilityShortcuts.boolean_rule?(rule)

        cheap_rule_minmax(rule)
      end

      def cheap_rule_minmax(rule)
        return [1, sides] if rule.type == :reroll_replace
        return unless sides == 1 && rule.type == :reroll_add

        value = 1 + (rule.applies?(1) ? [rule.limit, 0].max : 0)
        [value, value]
      end

      def safe_minmax
        return safe_mapped_minmax if @maps

        adds = positive_rule_limits(:reroll_add)
        subtracts = positive_rule_limits(:reroll_subtract)
        return [1, sides * (1 + adds)] if subtracts.zero?

        maximum = sides * (1 + adds + subtracts)
        [-maximum, maximum]
      end

      def safe_mapped_minmax
        unless @maps.all? { |rule| rule.instance_of?(MapRule) && ProbabilityShortcuts.boolean_rule?(rule) }
          raise ProbabilityLimitError, 'Cannot establish finite dice bounds within calculation limits'
        end

        [0, *@maps.map(&:mapped_value)].minmax
      end

      def positive_rule_limits(type)
        (@rerolls || []).sum { |rule| rule.type == type ? [rule.limit, 0].max : 0 }
      end

      def minmax_mappings(possible_values)
        possible_values.map do |x|
          map_val, = calc_maps(x)
          map_val
        end.minmax
      end

      # This isn't 100% accurate, but does cover most "normal" scenarios, and we're only falling back to it when we
      # have to. The inaccuracy is that min_result..max_result may contain 'holes' which have extreme map values that
      # cannot actually occur. In practice it is likely a non-issue unless someone went out of their way to invent a
      # dice schem that broke it.
      def logical_minmax
        return safe_minmax unless inexpensive_bounds?

        min_result, max_result = logical_rerolls_minmax
        if @maps
          return safe_minmax if (max_result - min_result + 1) * @maps.length > ProbabilityBudget::MAX_PREDICATES

          return minmax_mappings(min_result..max_result)
        end

        [min_result, max_result]
      end

      def inexpensive_bounds?
        rules = [*(@rerolls || []), *(@maps || [])]
        rules.all? { |rule| ordinary_boolean_rule?(rule) } &&
          sides * rules.length <= ProbabilityBudget::MAX_FACES
      end

      def ordinary_boolean_rule?(rule)
        (rule.instance_of?(RerollRule) || rule.instance_of?(MapRule)) && ProbabilityShortcuts.boolean_rule?(rule)
      end

      def logical_rerolls_minmax
        min_result = @basic_die.min
        max_result = @basic_die.max
        min_subtract = find_minimum_possible_subtract
        max_add = find_maximum_possible_adds
        min_result = [min_subtract - max_add, min_subtract - max_result].min if min_subtract
        [min_result, max_add + max_result]
      end

      def find_minimum_possible_subtract
        min_subtract = nil
        @rerolls.select { |r| r.type == :reroll_subtract }.each do |rule|
          min_reroll = @basic_die.all_values.select { |v| rule.applies?(v) }.min
          next unless min_reroll

          min_subtract = [min_reroll, min_subtract].compact.min
        end
        min_subtract
      end

      def find_maximum_possible_adds
        total_add = 0
        @rerolls.select { |r| r.type == :reroll_add }.each do |rule|
          max_reroll = @basic_die.all_values.select { |v| rule.applies?(v) }.max
          next unless max_reroll

          total_add += max_reroll * [rule.limit, 0].max
        end
        total_add
      end
    end
  end
end
