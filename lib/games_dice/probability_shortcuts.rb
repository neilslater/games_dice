# frozen_string_literal: true

module GamesDice
  # @!visibility private
  # Exact distributions for inexpensive ordinary reroll recipes.
  module ProbabilityShortcuts
    def self.boolean_rule?(rule)
      value = rule.trigger_value
      operator = rule.trigger_op
      return false unless value.method(operator).source_location.nil?
      return %i[== != < <= > >=].include?(operator) if value.instance_of?(Integer)

      value.instance_of?(Range) && value.begin.is_a?(Integer) && value.end.is_a?(Integer) &&
        %i[include? cover?].include?(operator)
    end

    private

    def shortcut
      return @die.basic_die.probabilities.to_h if @rerolls.empty?

      rule = shortcut_rule
      return unless rule
      return deterministic_add(rule) if @sides == 1 && rule.type == :reroll_add
      return replacement(rule) if rule.type == :reroll_replace

      nil
    end

    def shortcut_rule
      return unless @rerolls.one?

      rule = @rerolls.first
      rule if rule.instance_of?(RerollRule) && ProbabilityShortcuts.boolean_rule?(rule)
    end

    def deterministic_add(rule)
      @budget.predicate
      count = rule.applies?(1) ? [rule.limit, 0].max : 0
      { 1 + count => 1.0 }
    end

    def replacement(rule)
      triggers = triggering_faces(rule)
      count = triggers.count(true)
      return @die.basic_die.probabilities.to_h if count.zero? || count == @sides || rule.limit <= 0

      replacement_weights(triggers, count, rule.limit)
    end

    def replacement_weights(triggers, count, limit)
      repeated = ((count.to_f / @sides)**limit) / @sides
      terminal = (1.0 - (count * repeated)) / (@sides - count)
      triggers.each_with_index.to_h { |trigger, index| [index + 1, trigger ? repeated : terminal] }
    end

    def triggering_faces(rule)
      Array.new(@sides) do |index|
        @budget.face
        @budget.predicate
        rule.applies?(index + 1)
      end
    end
  end
end
