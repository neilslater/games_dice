# frozen_string_literal: true

module GamesDice
  class Bunch
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
        else
          raise ArgumentError, ":keep_mode can be nil, :keep_best or :keep_worst. Got #{options[:keep_mode].inspect}"
        end
      end

      def find_used_dice_due_to_keep_mode(used_dice, unused_dice = [])
        full_dice = result_details.sort_by(&:total)
        case @keep_mode
        when :keep_best
          used_dice = full_dice[-@keep_number..]
          unused_dice = full_dice[0..full_dice.length - 1 - @keep_number]
        when :keep_worst
          used_dice = full_dice[0..(@keep_number - 1)]
          unused_dice = full_dice[@keep_number..(full_dice.length - 1)]
        end

        [used_dice, unused_dice]
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
