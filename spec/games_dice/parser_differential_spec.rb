# frozen_string_literal: true

require 'helpers'
require_relative '../../research/parser/reference_parser'
require_relative '../../research/parser/scanner'
require_relative '../../research/parser/corpus'
require_relative '../../research/parser/comparison'

RSpec.describe GamesDice::Parser do
  let(:scanner) { described_class.new }
  let(:reference) { GamesDiceParserResearch::ReferenceParser.new }

  GamesDiceParserResearch::Corpus.differential.each_with_index do |input, index|
    it "matches reference acceptance and constructor data for case #{index}: #{input.inspect}" do
      expected = GamesDiceParserResearch::Comparison.outcome(reference, input)
      expect(GamesDiceParserResearch::Comparison.outcome(scanner, input)).to eq(expected)
    end
  end
end
