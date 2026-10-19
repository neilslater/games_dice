# frozen_string_literal: true

require 'games_dice/parser'

module GamesDiceParserResearch
  # Compares values and rejection while allowing the agreed error-class differences.
  module Comparison
    module_function

    def outcome(parser, input)
      [:accepted, parser.parse(input)]
    rescue Parslet::ParseFailed, ParseError, GamesDice::ParseError, ArgumentError, Encoding::CompatibilityError
      [:rejected]
    rescue RuntimeError => e
      raise unless e.message == 'Cannot set keepers for a bunch twice'

      [:rejected]
    end
  end
end
