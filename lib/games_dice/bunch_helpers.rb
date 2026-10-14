# frozen_string_literal: true

module GamesDice
  class Bunch
    # @!visibility private
    # Private distribution and aggregate-error helpers.
    module ProbabilityHelpers
      private

      def probabilities_for_budget(limit)
        refresh_recipe
        return @probabilities if valid_probability_cache?(limit)

        with_recipe do
          distribution = single_distribution(limit)
          result = repeated_distribution(distribution)
          @probability_error = ProbabilityBudget.check(ProbabilityBudget.scale(single_error, @ndice), limit)
          @probabilities = result
        end
      end

      def repeated_distribution(distribution)
        return distribution.repeat_sum(@ndice) unless @keep_mode && @ndice > @keep_number

        distribution.repeat_n_sum_k(@ndice, @keep_number, @keep_mode)
      end

      def single_error
        @single_die.is_a?(ComplexDie) ? @single_die.instance_variable_get(:@probability_error) : 0.0
      end

      def single_distribution(limit)
        return @single_die.probabilities unless @single_die.is_a?(ComplexDie)

        @single_die.__send__(:probabilities_for_budget, ProbabilityBudget.share(limit, @ndice))
      end
    end

    # @!visibility private
    # Private extension methods for GamesDice::Bunch keep rules
    module KeepHelpers
      private

      def keep_mode_from_hash(options)
        @keep_mode = options[:keep_mode]
        case @keep_mode
        when nil
          @keep_mode = nil
        when :keep_best, :keep_worst
          @keep_number = Integer(options[:keep_number] || 1)
          raise ArgumentError, ":keep_number must be 1 or more, but got #{@keep_number}" unless @keep_number.positive?
        else
          raise ArgumentError, ":keep_mode can be nil, :keep_best or :keep_worst. Got #{options[:keep_mode].inspect}"
        end
      end

      def explain_kept_dice(used_dice)
        separator = @single_die.maps ? ', ' : ' + '
        ". Keep: #{used_dice.map(&:explain_total).join(separator)}"
      end
    end

    # @!visibility private
    # Private extension methods for GamesDice::Bunch explaining
    module ExplainHelpers
      private

      def build_explanation(used_dice)
        if @keep_mode || @single_die.maps
          explanation = explain_with_keep_or_map(used_dice)
        else
          explanation = used_dice.map(&:explain_value).join(' + ')
          explanation += " = #{@result}" if @ndice > 1
        end

        explanation
      end

      def explain_with_keep_or_map(used_dice)
        explanation = result_details.map(&:explain_value).join(', ')
        explanation += explain_kept_dice(used_dice) if @keep_mode
        explanation += ". Successes: #{@result}" if @single_die.maps
        explanation += " = #{@result}" if @keep_mode && !@single_die.maps && @keep_number > 1

        explanation
      end
    end
  end
end
