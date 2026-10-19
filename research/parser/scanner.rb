# frozen_string_literal: true

require 'strscan'
require_relative 'scanner_modifiers'

# Development-only candidates and reference implementations; never loaded by the gem.
module GamesDiceParserResearch
  # Prototype of the proposed library-owned error hierarchy, isolated from production.
  class Error < StandardError; end

  # Positions are zero-based byte offsets into the original, unnormalized input.
  class ParseError < Error
    attr_reader :byte_offset

    def initialize(message, byte_offset)
      @byte_offset = byte_offset
      super("#{message} at byte #{byte_offset}")
    end
  end

  # Stateless reusable entry point. Each call owns its mutable scanning state.
  class Scanner
    def parse(description)
      scan(description.to_s)
    end

    private

    def scan(text)
      ScannerState.new(text).parse
    rescue ArgumentError, Encoding::CompatibilityError => e
      raise ParseError.new('Invalid or unsupported input encoding', 0), cause: e
    end
  end

  # Emits constructor hashes directly, without a token list or syntax tree.
  class ScannerState
    include ScannerModifiers

    FIRST_TERM = /([+-]?)\s*([0-9]+)(?:d([0-9]+))?/
    NEXT_TERM = /([+-])\s*([0-9]+)(?:d([0-9]+))?/

    def initialize(input)
      normalized = input.strip
      @leading_bytes = input.bytesize - input.lstrip.bytesize
      @scanner = StringScanner.new(normalized)
      @bunches = []
      @offset = 0
    end

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
end
