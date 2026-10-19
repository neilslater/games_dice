# frozen_string_literal: true

require 'helpers'
require_relative '../../research/parser/scanner'
require_relative '../../research/parser/corpus'

RSpec.describe GamesDiceParserResearch::Scanner, :aggregate_failures do
  [GamesDice::Parser, described_class].each do |parser_class|
    describe parser_class do
      let(:parser) { described_class.new }

      it 'coerces input to text without modifying the returned string' do
        text = "\0 + 02d006 - 3 \0"
        input = double(to_s: text)
        expect(parser.parse(input)).to eq(bunches: [{ ndice: 2, sides: 6, multiplier: 1 }], offset: -3)
        expect(text).to eq("\0 + 02d006 - 3 \0")
      end

      it 'preserves order, defaults, comparison reversal and negative mapping outputs' do
        result = parser.parse('2d6r:>=2,add,3.m:<4,-2,Hit.k:1,worst.x')
        expect(result).to eq(bunches: [{ ndice: 2, sides: 6, multiplier: 1,
                                         rerolls: [[2, :<=, :reroll_add, 3], [6, :==, :reroll_add]],
                                         maps: [[4, :>, -2, 'Hit']], keep_number: 1,
                                         keep_mode: :keep_worst }], offset: 0)
      end

      it 'preserves arbitrary precision without invoking constructors or rolling' do
        number = '9' * 100
        expect(parser.parse("#{number}d6+#{number}")).to eq(
          bunches: [{ ndice: number.to_i, sides: 6, multiplier: 1 }], offset: number.to_i
        )
      end

      it 'returns independent mutable results across calls' do
        first = parser.parse('2d6m:1,2,Hit.r1')
        second = parser.parse('2d6m:1,2,Hit.r1')
        first[:bunches][0][:maps][0][3].replace('Changed')
        first[:bunches][0][:rerolls].clear
        expect(second[:bunches][0]).to include(maps: [[1, :<=, 2, 'Hit']], rerolls: [[1, :>=, :reroll_replace]])
      end

      it 'recovers after a failed parse' do
        expected = parser.parse('1d6')
        expect { parser.parse('1d6?') }.to raise_error(StandardError)
        expect(parser.parse('1d6')).to eq(expected)
      end

      GamesDiceParserResearch::Corpus::CONSTRUCTOR_FAILURES.each do |input|
        it "keeps semantic validation in constructors for #{input}" do
          parsed = parser.parse(input)
          expect { GamesDice::Dice.new(parsed[:bunches], parsed[:offset]) }.to raise_error(ArgumentError)
        end
      end

      GamesDiceParserResearch::Corpus::INVALID.each do |input|
        it "rejects invalid input #{input.inspect}" do
          expect { parser.parse(input) }.to raise_error(StandardError)
        end
      end
    end
  end

  describe GamesDice::Parser do
    it 'exposes Parslet failure causes and normalized-input positions in the reference behavior' do
      expect { described_class.new.parse('1d6junk') }.to raise_error(Parslet::ParseFailed) { |error|
        expect(error.message).to include('line 1 char 5')
        expect(error.parse_failure_cause.ascii_tree).to include('Failed to match [+-]')
      }
    end
  end

  describe GamesDiceParserResearch::ParseError do
    it 'reports the original byte offset without an inserted leading sign' do
      expect { GamesDiceParserResearch::Scanner.new.parse('  1d6junk') }.to raise_error(described_class) { |error|
        expect(error.byte_offset).to eq(5)
        expect(error).to be_a(GamesDiceParserResearch::Error)
      }
    end
  end

  describe 'encoding and coercion failures' do
    it 'wraps malformed input encoding with its original cause' do
      expect { described_class.new.parse("1d6\xff") }.to raise_error(GamesDiceParserResearch::ParseError) { |error|
        expect(error.byte_offset).to eq(0)
        expect(error.cause).to be_a(ArgumentError).or be_a(Encoding::CompatibilityError)
      }
    end

    it 'wraps an unsupported ASCII-incompatible encoding' do
      input = '1d6'.encode(Encoding::UTF_16LE)
      expect { described_class.new.parse(input) }.to raise_error(GamesDiceParserResearch::ParseError)
    end

    it 'does not wrap exceptions raised by user coercion' do
      input = double
      allow(input).to receive(:to_s).and_raise(ArgumentError, 'caller failure')
      expect { described_class.new.parse(input) }.to raise_error(ArgumentError, 'caller failure')
    end
  end
end
