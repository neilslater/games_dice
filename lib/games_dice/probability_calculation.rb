# frozen_string_literal: true

require 'games_dice/probability_shortcuts'

module GamesDice
  # @api private
  # A bounded enumeration of completed rolls, with exact shortcuts for simple recipes.
  class ProbabilityCalculation
    include ProbabilityShortcuts

    State = Struct.new(:depth, :reason, :subtracting, :probability, :total, :remaining)
    private_constant :State

    # @return [Float] Certified omitted-mass bound after successful calculation.
    attr_reader :error

    def initialize(die, limit)
      @die = die
      @sides = die.sides
      @rerolls = die.rerolls&.dup || []
      @maps = die.maps&.dup
      @budget = ProbabilityBudget.new(limit, @sides)
      @probabilities = Hash.new(0.0)
    end

    # @return [Probabilities] Normalized distribution of completed outcomes.
    def calculate
      exact = shortcut
      enumerate(State.new(0, :basic, false, 1.0, nil, @rerolls.map(&:limit))) unless exact
      @probabilities = exact if exact
      @error = @budget.omitted
      normalize
      @probabilities = mapped_probabilities if @maps
      Probabilities.from_h(@probabilities)
    end

    private

    def enumerate(state)
      probability = state.probability / @sides
      depth = state.depth + 1
      (1..@sides).each do |face|
        @budget.face
        visit_face(state, face, depth, probability)
      end
    end

    def visit_face(state, face, depth, probability)
      total = next_total(state, face)
      index = @die.__send__(:find_matching_reroll_rule, face, depth, state.remaining, @budget, @rerolls)
      if index.nil?
        @probabilities[total] += probability
      elsif !@budget.omit?(depth, probability)
        continue_branch(state, total, index, depth, probability)
      end
    end

    def next_total(state, face)
      case state.reason
      when :reroll_add then state.total + face
      when :reroll_subtract then state.total - face
      when :reroll_use_best then [state.total, face].max
      when :reroll_use_worst then [state.total, face].min
      else face
      end
    end

    def continue_branch(state, total, index, depth, probability)
      rule = @rerolls[index]
      remaining = state.remaining.dup
      remaining[index] -= 1
      subtracting = state.subtracting || rule.type == :reroll_subtract
      reason = state.subtracting && rule.type == :reroll_add ? :reroll_subtract : rule.type
      enumerate(State.new(depth, reason, subtracting, probability, total, remaining))
    end

    def normalize
      mass = @probabilities.values.sum
      unless mass.finite? && mass.positive? && (mass + @error - 1.0).abs <= 1e-8
        raise ProbabilityLimitError,
              'Probability calculation cannot meet truncation error bound within calculation limits'
      end
      return if @error.zero?

      @probabilities.transform_values! { |probability| probability / mass }
    end

    def mapped_probabilities
      @probabilities.each_with_object(Hash.new(0.0)) do |(value, probability), mapped|
        result, = @die.__send__(:calc_maps, value, @budget, @maps)
        mapped[result] += probability
      end
    end
  end
end
