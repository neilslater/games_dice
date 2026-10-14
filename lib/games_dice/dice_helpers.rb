# frozen_string_literal: true

module GamesDice
  class Dice
    # @!visibility private
    # Private combination helpers sharing one truncation budget across bunches.
    module ProbabilityHelpers
      Combination = Struct.new(:distribution, :error)
      private_constant :Combination

      private

      def combined_probabilities
        per_die = ProbabilityBudget.share(ProbabilityBudget::LIMIT, [probability_dice_count, 1].max)
        result = Combination.new(Probabilities.new([1.0], @offset), 0.0)
        @bunches.zip(@bunch_multipliers).each do |bunch, multiplier|
          next if multiplier.zero?

          component = component_probabilities(bunch, per_die, result)
          result.distribution = Probabilities.add_distributions_mult(1, result.distribution, multiplier, component)
        end
        @probability_error = ProbabilityBudget.check(result.error, ProbabilityBudget::LIMIT)
        result.distribution
      end

      def probability_dice_count
        @bunches.each_with_index.sum { |bunch, index| @bunch_multipliers[index].zero? ? 0 : bunch.ndice }
      end

      def component_probabilities(bunch, per_die, result)
        component = bunch.__send__(:probabilities_for_budget, (per_die * bunch.ndice).prev_float)
        result.error = ProbabilityBudget.add(result.error, bunch.instance_variable_get(:@probability_error))
        component
      end
    end
  end
end
