# frozen_string_literal: true

module GamesDice
  # Raised when a probability query cannot meet its accuracy or work limits.
  class ProbabilityLimitError < RuntimeError; end

  # @api private
  # Tracks a conservative upper bound on omitted mass, separately from floating-point roundoff.
  class ProbabilityBudget
    # Strictly below the decimal aggregate truncation budget.
    LIMIT = 1e-10.prev_float
    # Maximum evaluated faces per component calculation.
    MAX_FACES = 100_000
    # Maximum reroll and mapping predicate calls per component calculation.
    MAX_PREDICATES = 1_000_000
    # Maximum number of face draws along one enumerated history.
    MAX_DEPTH = 64

    # @return [Float] Upward-rounded omitted probability mass.
    attr_reader :omitted

    def initialize(limit, sides)
      @limit = limit
      @sides = sides
      @omitted = 0.0
      @upper = [1.0]
      @faces = @predicates = 0
    end

    # Counts one evaluated face, refusing work above the cap.
    def face
      @faces += 1
      work_limit if @faces > MAX_FACES
    end

    # Counts one rule invocation, including shortcut and map predicates.
    def predicate
      @predicates += 1
      work_limit if @predicates > MAX_PREDICATES
    end

    def omit?(depth, probability)
      return false if depth < 20 && probability >= 1e-16

      @upper << (@upper.last / @sides).next_float while @upper.length <= depth
      total = (@omitted + @upper[depth]).next_float
      if total <= @limit
        @omitted = total
        return true
      end
      return false if depth < MAX_DEPTH

      raise ProbabilityLimitError,
            'Probability calculation cannot meet truncation error bound within calculation limits'
    end

    # Allocates a downward-rounded share of an aggregate error budget.
    def self.share(limit, count)
      (limit / count).prev_float
    end

    # Bounds a union of repeated independent component errors.
    def self.scale(error, count)
      error.zero? ? 0.0 : (error * count).next_float
    end

    # Adds achieved error bounds with outward rounding and exact zero handling.
    def self.add(left, right)
      return left if right.zero?
      return right if left.zero?

      (left + right).next_float
    end

    # Validates a complete aggregate certificate before its distribution is cached.
    def self.check(error, limit)
      if error > limit
        raise ProbabilityLimitError,
              'Probability calculation cannot meet truncation error bound within calculation limits'
      end
      error
    end

    private

    def work_limit
      raise ProbabilityLimitError, 'Probability calculation exceeds work limit'
    end
  end
end
