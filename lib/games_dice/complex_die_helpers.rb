# frozen_string_literal: true

module GamesDice
  # @!visibility private
  # Private extension methods for GamesDice::ComplexDie
  module ComplexDieHelpers
    private

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
end
