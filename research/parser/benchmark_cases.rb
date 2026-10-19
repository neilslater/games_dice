# frozen_string_literal: true

require_relative 'corpus'
require_relative 'factory'

module GamesDiceParserResearch
  # Builds workloads outside the timed region, using equivalent factory paths.
  module BenchmarkCases
    module_function

    def valid_inputs
      Corpus::ORDINARY.map { |text| ['ordinary', text] } +
        [%w[constant 5], %w[many_dice 100d6], ['many_bunches', (['1d6'] * 20).join('+')],
         ['many_modifiers', "1d6#{'r:1,replace,1.m:>=5,1.' * 20}"]]
    end

    def valid_operations(parser, text)
      parsed = parser.parse(text)
      cached = construct(parsed)
      { parse: -> { parser.parse(text) }, construct: -> { construct(parsed) }, roll: -> { cached.roll },
        construct_roll: -> { construct(parsed).roll } }.merge(factory_operations(parser, text))
    end

    def factory_operations(parser, text)
      factory = factory_for(parser)
      { create: -> { factory.create(text) }, create_roll: -> { factory.create(text).roll } }
    end

    def factory_for(parser)
      parser.is_a?(GamesDice::Parser) ? GamesDice : Factory.new(parser)
    end

    def construct(parsed)
      GamesDice::Dice.new(parsed[:bunches], parsed[:offset])
    end

    def varied_operations(parser, text)
      texts = (0...16).map { |offset| "#{text}+#{offset}" }
      factory = factory_for(parser)
      dice = texts.map { |input| factory.create(input) }
      { parse: rotating(texts) { |input| parser.parse(input) },
        roll: rotating(dice, &:roll), create_roll: rotating(texts) { |input| factory.create(input).roll } }
    end

    def rotating(items)
      index = -1
      lambda do
        index = (index + 1) % items.length
        yield items[index]
      end
    end

    def invalid_inputs
      [10, 100, 1000].flat_map do |length|
        [['invalid_start', "?#{'1' * length}"], ['invalid_end', "#{'1' * length}?"]]
      end + [['invalid_modifier', '1d6r:>=1,replace,'], ['duplicate_keeper', '4d6k1k2']]
    end

    def failure_operation(parser, text, render: false)
      lambda do
        parser.parse(text)
      rescue Parslet::ParseFailed, Error, GamesDice::ParseError, ArgumentError, RuntimeError => e
        render ? diagnostic(e) : nil
      end
    end

    def constructor_failures(parser, text)
      factory = factory_for(parser)
      parsed = parser.parse(text)
      { create_reject: -> { reject_constructor { factory.create(text) } },
        construct_reject: -> { reject_constructor { construct(parsed) } } }
    end

    def reject_constructor
      yield
    rescue ArgumentError
      nil
    end

    def diagnostic(error)
      error.respond_to?(:parse_failure_cause) ? error.parse_failure_cause.ascii_tree : error.message
    end
  end
end
