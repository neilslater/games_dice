# frozen_string_literal: true

require 'json'
require_relative 'reference_parser'
require_relative 'scanner'
require_relative 'corpus'
require_relative 'comparison'

module GamesDiceParserResearch
  # Larger reproducible differential sweep outside the routine spec corpus.
  class Compare
    def initialize(seed:, count:)
      @seed = seed
      @count = count
      @reference = ReferenceParser.new
      @scanner = Scanner.new
    end

    def run
      valid = Corpus.generated(seed: @seed, count: @count)
      inputs = valid + Corpus.mutations(valid, seed: @seed + 1)
      mismatches = inputs.filter_map { |text| mismatch(text) }
      { seed: @seed, generated: @count, comparisons: inputs.length, mismatches: mismatches }
    end

    private

    def mismatch(text)
      expected = Comparison.outcome(@reference, text)
      actual = Comparison.outcome(@scanner, text)
      { input: text, expected: expected, actual: actual } unless expected == actual
    end
  end
end

if $PROGRAM_NAME == __FILE__
  result = GamesDiceParserResearch::Compare.new(seed: Integer(ENV.fetch('SEED', '20261021')),
                                                count: Integer(ENV.fetch('COUNT', '2000'))).run
  puts JSON.generate(result)
  exit 1 unless result[:mismatches].empty?
end
