# frozen_string_literal: true

require 'helpers'

describe GamesDice::RerollRule do
  describe '#new' do
    it 'should accept self-consistent operator/value pairs as a trigger' do
      GamesDice::RerollRule.new(5, :>, :reroll_subtract)
      GamesDice::RerollRule.new((1..5), :member?, :reroll_replace)
    end

    it 'should reject inconsistent operator/value pairs for a trigger' do
      expect(-> { GamesDice::RerollRule.new(5, :member?, :reroll_subtract) }).to raise_error(ArgumentError)
      expect(-> { GamesDice::RerollRule.new((1..5), :>, :reroll_replace) }).to raise_error(ArgumentError)
    end

    it 'should reject bad re-roll types' do
      expect(-> { GamesDice::RerollRule.new(5, :>, :reroll_again) }).to raise_error(ArgumentError)
      expect(-> { GamesDice::RerollRule.new((1..5), :member?, 42) }).to raise_error(ArgumentError)
    end
  end

  describe '#applies?' do
    it 'should return true if a trigger condition is met' do
      rule = GamesDice::RerollRule.new(5, :>, :reroll_subtract)
      expect(rule.applies?(4)).to be true

      rule = GamesDice::RerollRule.new((1..5), :member?, :reroll_subtract)
      expect(rule.applies?(4)).to be true
    end

    it 'should return false if a trigger condition is not met' do
      rule = GamesDice::RerollRule.new(5, :>, :reroll_subtract)
      expect(rule.applies?(7)).to be false

      rule = GamesDice::RerollRule.new((1..5), :member?, :reroll_subtract)
      expect(rule.applies?(6)).to be false
    end
  end
end
