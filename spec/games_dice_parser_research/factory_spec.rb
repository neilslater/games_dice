# frozen_string_literal: true

require 'helpers'
require_relative '../../research/parser/factory'
require_relative '../../research/parser/reference_parser'
require_relative '../../research/parser/corpus'

RSpec.describe GamesDiceParserResearch::Factory, :aggregate_failures do
  let(:factory) { described_class.new(GamesDiceParserResearch::ReferenceParser.new) }

  GamesDiceParserResearch::Corpus::ORDINARY.each do |input|
    it "matches production seeded roll sequences against the retained parser and explanations for #{input}" do
      expected = GamesDice.create(input, Random.new(10))
      actual = factory.create(input, Random.new(10))
      30.times do
        expect([actual.roll, actual.explain_result]).to eq([expected.roll, expected.explain_result])
      end
    end
  end

  it 'does not share injected generators between successive results' do
    first = factory.create('1d6', Random.new(10))
    factory.create('1d6', Random.new(20))
    expected = GamesDice.create('1d6', Random.new(10))
    expect(Array.new(10) { first.roll }).to eq(Array.new(10) { expected.roll })
  end
end
