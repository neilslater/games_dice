# frozen_string_literal: true

require 'helpers'

describe GamesDice::MapRule do
  describe '#new' do
    it 'should accept self-consistent operator/value pairs as a trigger' do
      GamesDice::MapRule.new(5, :>, 1)
      GamesDice::MapRule.new((1..5), :member?, 17)
    end

    it 'should reject inconsistent operator/value pairs for a trigger' do
      expect(-> { GamesDice::MapRule.new(5, :member?, -1) }).to raise_error(ArgumentError)
      expect(-> { GamesDice::MapRule.new((1..5), :>, 12) }).to raise_error(ArgumentError)
    end

    it 'should reject non-Integer map results' do
      expect(-> { GamesDice::MapRule.new(5, :>, :reroll_again) }).to raise_error(TypeError)
      expect(-> { GamesDice::MapRule.new((1..5), :member?, 'foo') }).to raise_error(TypeError)
    end
  end

  describe '#map_from' do
    it 'should return the mapped value for a match' do
      rule = GamesDice::MapRule.new(5, :>, -1)
      expect(rule.map_from(4)).to eql(-1)

      rule = GamesDice::MapRule.new((1..5), :member?, 3)
      expect(rule.map_from(4)).to eql 3
    end

    it 'should return nil for no match' do
      rule = GamesDice::MapRule.new(5, :>, -1)
      expect(rule.map_from(6)).to be_nil

      rule = GamesDice::MapRule.new((1..5), :member?, 3)
      expect(rule.map_from(6)).to be_nil
    end
  end
end
