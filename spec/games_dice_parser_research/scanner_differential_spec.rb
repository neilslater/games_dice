# frozen_string_literal: true

require 'helpers'
require 'digest'
require_relative '../../research/parser/reference_parser'
require_relative '../../research/parser/scanner'
require_relative '../../research/parser/corpus'
require_relative '../../research/parser/comparison'

RSpec.describe GamesDiceParserResearch::Scanner do
  let(:scanner) { described_class.new }
  let(:reference) { GamesDiceParserResearch::ReferenceParser.new }

  GamesDiceParserResearch::Corpus.differential.each_with_index do |input, index|
    it "matches reference acceptance and constructor data for case #{index}: #{input.inspect}" do
      expected = GamesDiceParserResearch::Comparison.outcome(reference, input)
      expect(GamesDiceParserResearch::Comparison.outcome(scanner, input)).to eq(expected)
    end
  end

  it 'retains the source parser snapshot with only namespace and class renaming' do
    path = File.expand_path('../../research/parser/reference_parser.rb', __dir__)
    snapshot = File.read(path).sub(/# Reference snapshot:.*?require 'parslet'/m, "require 'parslet'")
    snapshot = snapshot.sub('module GamesDiceParserResearch', 'module GamesDice')
    snapshot = snapshot.sub('class ReferenceParser <', 'class Parser <')
    expect(Digest::SHA256.hexdigest(snapshot)).to eq('f719768638bfaeed62be29f2d2f91bc423f3689535e0120f9c75c75b038640ef')
  end

  it 'does not add prototype error classes to the production namespace' do
    expect(GamesDice.const_defined?(:Error, false)).to be(false)
  end
end
