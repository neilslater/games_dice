# frozen_string_literal: true

module GamesDice
  # Base class for library-owned parsing errors.
  # Existing constructor and probability exception hierarchies remain independent.
  class Error < StandardError; end

  # Invalid dice notation or an invalid/unsupported input encoding.
  # Messages are readable diagnostics, not a stable text interface.
  class ParseError < Error
    # Zero-based byte offset into the original input, before whitespace stripping.
    # Encoding failures use zero to identify the input as a whole.
    # @return [Integer]
    attr_reader :byte_offset

    # Creates a diagnostic for the original input.
    # @param [String] message Description of the invalid notation.
    # @param [Integer] byte_offset Zero-based original-input byte position.
    def initialize(message, byte_offset)
      @byte_offset = byte_offset
      super("#{message} at byte #{byte_offset}")
    end
  end
end
