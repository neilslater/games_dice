# frozen_string_literal: true

require 'helpers'

describe GamesDice::RerollRule, :aggregate_failures do
  describe '#new' do
    it 'accept self-consistent operator/value pairs as a trigger' do
      expect { described_class.new(5, :>, :reroll_subtract) }.not_to raise_error
      expect { described_class.new(1..5, :member?, :reroll_replace) }.not_to raise_error
    end

    it 'reject inconsistent operator/value pairs for a trigger' do
      expect { described_class.new(5, :member?, :reroll_subtract) }.to raise_error(ArgumentError)
      expect { described_class.new(1..5, :>, :reroll_replace) }.to raise_error(ArgumentError)
    end

    it 'reject bad re-roll types' do
      expect { described_class.new(5, :>, :reroll_again) }.to raise_error(ArgumentError)
      expect { described_class.new(1..5, :member?, 42) }.to raise_error(ArgumentError)
    end
  end

  describe '#applies?' do
    it 'return true if a trigger condition is met' do
      rule = described_class.new(5, :>, :reroll_subtract)
      expect(rule.applies?(4)).to be true

      rule = described_class.new(1..5, :member?, :reroll_subtract)
      expect(rule.applies?(4)).to be true
    end

    it 'return false if a trigger condition is not met' do
      rule = described_class.new(5, :>, :reroll_subtract)
      expect(rule.applies?(7)).to be false

      rule = described_class.new(1..5, :member?, :reroll_subtract)
      expect(rule.applies?(6)).to be false
    end
  end
end
