# frozen_string_literal: true

module GamesDice
  # @!visibility private
  # Private extension methods for GamesDice::ComplexDie
  module ComplexDieHelpers
    private

    def recursive_probabilities(probabilities = {}, prior_probability = 1.0, depth = 0, prior_result = nil, rerolls_left = nil, roll_reason = :basic, subtracting = false)
      each_probability = prior_probability / @basic_die.sides
      depth += 1
      if depth >= 20 || each_probability < 1.0e-16
        @probabilities_complete = false
        stop_recursing = true
      end

      @basic_die.each_value do |v|
        recurse_probs_for_value(v, roll_reason, probabilities, each_probability, depth, prior_result, rerolls_left,
                                subtracting, stop_recursing)
      end
      probabilities
    end

    def recurse_probs_for_value(v, roll_reason, probabilities, each_probability, depth, prior_result, rerolls_left, subtracting, stop_recursing)
      # calculate value, recurse if there is a reroll
      result_so_far, rerolls_remaining = calc_result_so_far(prior_result, rerolls_left, v, roll_reason)

      # Find which rule, if any, is being triggered
      rule_idx = find_matching_reroll_rule(v, result_so_far.rolls.length, rerolls_remaining)

      if rule_idx && !stop_recursing
        recurse_probs_with_rule(probabilities, each_probability, depth, result_so_far, rerolls_remaining, rule_idx,
                                subtracting)
      else
        t = result_so_far.total
        probabilities[t] ||= 0.0
        probabilities[t] += each_probability
      end
    end

    def recurse_probs_with_rule(probabilities, each_probability, depth, result_so_far, rerolls_remaining, rule_idx, subtracting)
      rule = @rerolls[rule_idx]
      rerolls_remaining[rule_idx] -= 1
      is_subtracting = true if subtracting || rule.type == :reroll_subtract

      # Apply the rule (note reversal for additions, after a subtract)
      if subtracting && rule.type == :reroll_add
        recursive_probabilities probabilities, each_probability, depth, result_so_far, rerolls_remaining,
                                :reroll_subtract, is_subtracting
      else
        recursive_probabilities probabilities, each_probability, depth, result_so_far, rerolls_remaining, rule.type,
                                is_subtracting
      end
    end

    def calc_result_so_far(prior_result, rerolls_left, v, roll_reason)
      if prior_result
        result_so_far = prior_result.clone
        result_so_far.add_roll(v, roll_reason)
        rerolls_remaining = rerolls_left.clone
      else
        result_so_far = GamesDice::DieResult.new(v, roll_reason)
        rerolls_remaining = @rerolls.map(&:limit)
      end
      [result_so_far, rerolls_remaining]
    end
  end
end
