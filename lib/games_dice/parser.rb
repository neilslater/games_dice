# frozen_string_literal: true

require 'games_dice/errors'
require 'games_dice/parser_state'

module GamesDice
  # Parses dice notation directly into constructor data without caching definitions.
  # Instances can be reused; each call owns its mutable scanning state and results.
  class Parser
    # Converts an entire dice expression into options for {Dice}.
    # @param [#to_s] description Dice notation, such as '2d20k1+5'.
    # @return [Hash] Independent :bunches array and signed :offset integer.
    # @raise [ParseError] For invalid notation or unsupported/invalid input encoding.
    #   Exceptions raised by the input's #to_s method propagate unchanged.
    def parse(description)
      scan(description.to_s)
    end

    private

    def scan(text)
      State.new(text).parse
    rescue ArgumentError, Encoding::CompatibilityError => e
      raise ParseError.new('Invalid or unsupported input encoding', 0), cause: e
    end
  end
end
