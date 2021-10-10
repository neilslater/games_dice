# frozen_string_literal: true

module GamesDice
  class ComplexDie
    # @!visibility private
    # Private extension methods for GamesDice::ComplexDie probability calculations
    module ProbabilityHelpers
      private

      def calculate_probabilities
        if @rerolls && @maps
          GamesDice::Probabilities.from_h(prob_hash_with_rerolls_and_maps)
        elsif @rerolls
          GamesDice::Probabilities.from_h(recursive_probabilities)
        elsif @maps
          GamesDice::Probabilities.from_h(prob_hash_with_just_maps)
        else
          @basic_die.probabilities
        end
      end

      def prob_hash_with_rerolls_and_maps
        prob_hash = {}
        reroll_probs = recursive_probabilities
        reroll_probs.each do |v, p|
          add_mapped_to_prob_hash(prob_hash, v, p)
        end
        prob_hash
      end

      def prob_hash_with_just_maps
        prob_hash = {}
        @basic_die.probabilities.each do |v, p|
          add_mapped_to_prob_hash(prob_hash, v, p)
        end
        prob_hash
      end

      def add_mapped_to_prob_hash(prob_hash, orig_val, prob)
        mapped_val, = calc_maps(orig_val)
        prob_hash[mapped_val] ||= 0.0
        prob_hash[mapped_val] += prob
      end

      RecurseStack = Struct.new(:depth, :roll_reason, :subtracting, :probabilities, :prior_probability, :prior_result,
                                :rerolls_left) do
        def initialize
          self.depth = 0
          self.roll_reason = :basic
          self.subtracting = false
          self.probabilities = {}
          self.prior_probability = 1.0
        end
      end

      def recursive_probabilities(stack = RecurseStack.new)
        stack.prior_probability = stack.prior_probability / @basic_die.sides
        stack.depth += 1

        @basic_die.each_value do |die_val|
          recurse_probs_for_value(die_val, stack)
        end
        stack.probabilities
      end

      def recurse_probs_for_value(die_val, stack)
        result_so_far, rerolls_remaining = calc_result_so_far(die_val, stack)
        rule_idx = find_matching_reroll_rule(die_val, result_so_far.rolls.length, rerolls_remaining)

        if conintue_recursing?(stack, rule_idx)
          continue_recursion(stack, result_so_far, rerolls_remaining, rule_idx)
        else
          end_recursion_store_probs(stack, result_so_far)
        end
      end

      def conintue_recursing?(stack, rule_idx)
        if stack.depth >= 20 || stack.prior_probability < 1.0e-16
          @probabilities_complete = false
          return false
        end

        !rule_idx.nil?
      end

      def continue_recursion(stack, result_so_far, rerolls_remaining, rule_idx)
        rule = @rerolls[rule_idx]
        rerolls_remaining[rule_idx] -= 1
        recurse_probs_with_rule(stack, result_so_far, rerolls_remaining, rule)
      end

      def end_recursion_store_probs(stack, result_so_far)
        t = result_so_far.total
        stack.probabilities[t] ||= 0.0
        stack.probabilities[t] += stack.prior_probability
      end

      def recurse_probs_with_rule(stack, result_so_far, rerolls_remaining, rule)
        next_stack = stack.clone
        next_stack.prior_result = result_so_far
        next_stack.rerolls_left = rerolls_remaining
        next_stack.subtracting = true if stack.subtracting || rule.type == :reroll_subtract

        # Apply the rule (note reversal for additions, after a subtract)
        next_stack.roll_reason = if stack.subtracting && rule.type == :reroll_add
                                   :reroll_subtract
                                 else
                                   rule.type
                                 end

        recursive_probabilities next_stack
      end

      def calc_result_so_far(die_val, stack)
        if stack.prior_result
          result_so_far = stack.prior_result.clone
          rerolls_remaining = stack.rerolls_left.clone
          result_so_far.add_roll(die_val, stack.roll_reason)
        else
          rerolls_remaining = @rerolls.map(&:limit)
          result_so_far = GamesDice::DieResult.new(die_val, stack.roll_reason)
        end
        [result_so_far, rerolls_remaining]
      end
    end

    # @!visibility private
    # Private extension methods for GamesDice::ComplexDie simulating rolls
    module RollHelpers
      private

      def roll_apply_rerolls
        return unless @rerolls

        subtracting = false
        rerolls_remaining = @rerolls.map(&:limit)

        rerolls_loop(subtracting, rerolls_remaining)
      end

      def rerolls_loop(subtracting, rerolls_remaining)
        loop do
          rule_idx = find_matching_reroll_rule(@basic_die.result, @result.rolls.length, rerolls_remaining)
          break unless rule_idx

          rule = @rerolls[rule_idx]
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
      def find_matching_reroll_rule(check_value, num_rolls, rerolls_remaining)
        @rerolls.zip(rerolls_remaining).find_index do |rule, remaining|
          next if rule.type == :reroll_subtract && num_rolls > 1

          remaining.positive? && rule.applies?(check_value)
        end
      end

      def roll_apply_maps
        return unless @maps

        m, n = calc_maps(@result.value)
        @result.apply_map(m, n)
      end

      def calc_maps(original_value)
        y = 0
        n = ''
        @maps.find do |rule|
          if (maybe_y = rule.map_from(original_value))
            y = maybe_y
            n = rule.mapped_name
          end
          maybe_y
        end
        [y, n]
      end
    end

    # @!visibility private
    # Private extension methods for GamesDice::ComplexDie calculating min and max (which is surprisingly complex)
    module MinMaxHelpers
      private

      def calc_minmax
        @min_result = probabilities.min
        @max_result = probabilities.max
        return if @probabilities_complete

        logical_min, logical_max = logical_minmax
        @min_result, @max_result = [@min_result, @max_result, logical_min, logical_max].minmax
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
        return @basic_die.minmax unless @rerolls || @maps
        return minmax_mappings(@basic_die.all_values) unless @rerolls

        min_result, max_result = logical_rerolls_minmax
        return minmax_mappings((min_result..max_result)) if @maps

        [min_result, max_result]
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

          total_add += max_reroll * rule.limit
        end
        total_add
      end
    end
  end
end
