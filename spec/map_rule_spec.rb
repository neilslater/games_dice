# frozen_string_literal: true

require 'helpers'

describe GamesDice::MapRule do
  describe '#new' do
    it 'accept self-consistent operator/value pairs as a trigger' do
      expect { described_class.new(5, :>, 1) }.not_to raise_error
      expect { described_class.new(1..5, :member?, 17) }.not_to raise_error
    end

    it 'reject inconsistent operator/value pairs for a trigger' do
      expect { described_class.new(5, :member?, -1) }.to raise_error(ArgumentError)
      expect { described_class.new(1..5, :>, 12) }.to raise_error(ArgumentError)
    end

    it 'reject non-Integer map results' do
      expect { described_class.new(5, :>, :reroll_again) }.to raise_error(TypeError)
      expect { described_class.new(1..5, :member?, 'foo') }.to raise_error(TypeError)
    end
  end

  describe '#map_from' do
    it 'return the mapped value for a match' do
      rule = described_class.new(5, :>, -1)
      expect(rule.map_from(4)).to be(-1)

      rule = described_class.new(1..5, :member?, 3)
      expect(rule.map_from(4)).to be 3
    end

    it 'return nil for no match' do
      rule = described_class.new(5, :>, -1)
      expect(rule.map_from(6)).to be_nil

      rule = described_class.new(1..5, :member?, 3)
      expect(rule.map_from(6)).to be_nil
    end
  end
end
