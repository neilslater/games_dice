# frozen_string_literal: true

require 'strscan'
require 'games_dice/parser_modifiers'

module GamesDice
  class Parser
    # Emits constructor hashes directly, without a token list or syntax tree.
    class State
      include Modifiers

      # Initial term permits an omitted plus sign, as in 2d6.
      FIRST_TERM = /([+-]?)\s*([0-9]+)(?:d([0-9]+))?/
      # Subsequent terms require an explicit sign to prevent prefix acceptance.
      NEXT_TERM = /([+-])\s*([0-9]+)(?:d([0-9]+))?/

      # Starts a fresh scan without mutating the original string.
      # @param [String] input Original text, before boundary whitespace removal.
      def initialize(input)
        normalized = input.strip
        @leading_bytes = input.bytesize - input.lstrip.bytesize
        @scanner = StringScanner.new(normalized)
        @bunches = []
        @offset = 0
      end

      # Scans all terms and returns independent constructor data.
      # @return [Hash] Bunch options and signed constant offset.
      # @raise [ParseError] If input cannot be fully consumed.
      def parse
        term(FIRST_TERM)
        term(NEXT_TERM) until @scanner.eos?
        { bunches: @bunches, offset: @offset }
      end

      private

      def term(pattern)
        fail_at('Expected signed dice term or integer') unless @scanner.scan(pattern)
        multiplier = @scanner[1] == '-' ? -1 : 1
        number = @scanner[2].to_i
        sides = @scanner[3]
        sides ? add_bunch(number, sides.to_i, multiplier) : @offset += multiplier * number
        @scanner.skip(/\s*/)
      end

      def add_bunch(number, sides, multiplier)
        bunch = { ndice: number, sides: sides, multiplier: multiplier }
        modifiers(bunch)
        @bunches << bunch
      end

      def fail_at(message)
        raise ParseError.new(message, @leading_bytes + @scanner.pos)
      end
    end

    private_constant :State
  end
end
