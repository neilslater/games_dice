# frozen_string_literal: true

module GamesDiceParserResearch
  # Measures a prepared callable; setup, warmup, GC.start and reporting are untimed.
  class Measurement
    def initialize(iterations:, warmup:, seed:)
      @iterations = iterations
      @warmup = warmup
      @seed = seed
    end

    def call(operation)
      srand(@seed)
      @warmup.times { operation.call }
      GC.start
      before = GC.stat(:total_allocated_objects)
      elapsed = elapsed_time(operation)
      objects = GC.stat(:total_allocated_objects) - before
      { iterations: @iterations, us: elapsed * 1_000_000 / @iterations,
        objects: objects.fdiv(@iterations), operations_per_second: @iterations / elapsed }
    end

    private

    def elapsed_time(operation)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @iterations.times { operation.call }
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    end
  end
end
