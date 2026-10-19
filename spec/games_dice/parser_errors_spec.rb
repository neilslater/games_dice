# frozen_string_literal: true

require 'helpers'

RSpec.describe GamesDice::Parser, :aggregate_failures do
  let(:parser) { described_class.new }

  { '  1d6junk' => 5, "\0\t1d6r:" => 5, '4d6k1k2' => 7, "1d6\n+?" => 4, '' => 0 }.each do |input, offset|
    it "reports an original-input byte offset for #{input.inspect}" do
      expect { parser.parse(input) }.to raise_error(GamesDice::ParseError) { |error|
        expect(error.byte_offset).to eq(offset)
        expect(error).to be_a(GamesDice::Error)
        expect(error.message).not_to be_empty
      }
    end
  end

  it 'wraps malformed input encoding with its original cause' do
    expect { parser.parse("1d6\xff") }.to raise_error(GamesDice::ParseError) { |error|
      expect(error.byte_offset).to eq(0)
      expect(error.cause).to be_a(ArgumentError).or be_a(Encoding::CompatibilityError)
    }
  end

  it 'wraps an unsupported ASCII-incompatible encoding' do
    input = '1d6'.encode(Encoding::UTF_16LE)
    expect { parser.parse(input) }.to raise_error(GamesDice::ParseError) { |error|
      expect(error.byte_offset).to eq(0)
      expect(error.cause).not_to be_nil
    }
  end

  it 'does not wrap exceptions raised by user coercion' do
    input = double
    allow(input).to receive(:to_s).and_raise(ArgumentError, 'caller failure')
    expect { parser.parse(input) }.to raise_error(ArgumentError, 'caller failure')
  end

  it 'exposes the same parse error through the public factory' do
    expect { GamesDice.create('1d6?') }.to raise_error(GamesDice::ParseError)
  end

  it 'leaves semantic validation failures in the constructor' do
    expect { GamesDice.create('0d6') }.to raise_error(ArgumentError)
  end

  it 'does not expose the retired Parslet diagnostic tree' do
    expect { parser.parse('?') }.to raise_error(GamesDice::ParseError) { |error|
      expect(error).not_to respond_to(:parse_failure_cause)
    }
  end
end
