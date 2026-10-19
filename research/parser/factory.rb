# frozen_string_literal: true

module GamesDiceParserResearch
  # Mirrors GamesDice.create without changing its global parser or public API.
  class Factory
    def initialize(parser)
      @parser = parser
    end

    def create(description, prng = nil)
      parsed = @parser.parse(description)
      parsed[:bunches].each { |bunch| bunch.merge!(prng: prng) } if prng
      GamesDice::Dice.new(parsed[:bunches], parsed[:offset])
    end
  end
end
