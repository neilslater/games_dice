# frozen_string_literal: true

require 'helpers'

describe GamesDice::ComplexDie, :aggregate_failures do
  before do
    # Set state of default PRNG
    srand(4567)
  end

  it 'represent a basic die as an object' do
    die = described_class.new(6)
    expect(die.min).to be 1
    expect(die.max).to be 6
    expect(die.sides).to be 6
  end

  it "return results based on Ruby's internal rand() by default" do
    die = described_class.new(10)
    [5, 4, 10, 4, 7, 8, 1, 9].each do |expected|
      expect(die.roll.value).to eql expected
      expect(die.result.value).to eql expected
    end
  end

  it 'use any object with a rand(Integer) method' do
    die = described_class.new(20, prng: TestPRNG.new)
    [16, 7, 3, 11, 16, 18, 20, 7].each do |expected|
      expect(die.roll.value).to eql expected
      expect(die.result.value).to eql expected
    end
  end

  it 'optionally accept a rerolls param' do
    valid = [[], [GamesDice::RerollRule.new(6, :<=, :reroll_add)],
             [GamesDice::RerollRule.new(6, :<=, :reroll_add), GamesDice::RerollRule.new(1, :>=, :reroll_subtract)],
             [[6, :<=, :reroll_add]], [[6, :<=, :reroll_add], [1, :>=, :reroll_subtract]]]
    invalid = [[7, TypeError], [['hello'], TypeError],
               [[GamesDice::RerollRule.new(6, :<=, :reroll_add), :reroll_add], TypeError], [[7], TypeError],
               [[['hello']], ArgumentError], [[[6, :<=, :reroll_add], :reroll_add], TypeError]]
    expect_rule_arguments(described_class, :rerolls, valid: valid, invalid: invalid)
  end

  it 'optionally accept a maps param' do
    valid = [[], [GamesDice::MapRule.new(7, :<=, 1)],
             [GamesDice::MapRule.new(7, :<=, 1), GamesDice::MapRule.new(1, :>, -1)],
             [[7, :<=, 1]], [[7, :<=, 1], [1, :>, -1]]]
    invalid = [[7, TypeError], [[7], TypeError], [[[7]], ArgumentError], [['hello'], TypeError],
               [[GamesDice::MapRule.new(7, :<=, 1), GamesDice::RerollRule.new(6, :<=, :reroll_add)], TypeError]]
    expect_rule_arguments(described_class, :maps, valid: valid, invalid: invalid)
  end

  describe 'with rerolls' do
    it 'calculate correct minimum and maximum results' do
      cases = [[[GamesDice::RerollRule.new(10, :<=, :reroll_add, 3)], [1, 40]],
               [[[1, :>=, :reroll_subtract]], [-9, 10]],
               [[GamesDice::RerollRule.new(10, :<=, :reroll_add)], [1, 10_010]]]
      cases.each do |rerolls, expected|
        die = described_class.new(10, rerolls: rerolls)
        expect(die).to have_attributes(min: expected.first, max: expected.last)
      end
    end

    it 'simulate a d10 that rerolls and adds on a result of 10' do
      die = described_class.new(10, rerolls: [[10, :<=, :reroll_add]])
      [5, 4, 14, 7, 8, 1, 9].each do |expected|
        expect(die.roll.value).to eql expected
        expect(die.result.value).to eql expected
      end
    end

    it 'explain how it got results outside range 1 to 10 on a d10' do
      die = described_class.new(10, rerolls: [[10, :<=, :reroll_add], [1, :>=, :reroll_subtract]])
      ['5', '4', '[10+4] 14', '7', '8', '[1-9] -8'].each do |expected|
        die.roll
        expect(die.explain_result).to eql expected
      end
    end

    it 'calculate an expected result' do
      cases = [[10, [[10, :<=, :reroll_add], [1, :>=, :reroll_subtract]], 5.5],
               [10, [GamesDice::RerollRule.new(1, :<=, :reroll_use_best, 1)], 7.15],
               [10, [GamesDice::RerollRule.new(1, :<=, :reroll_use_worst, 2)], 3.025],
               [6, [GamesDice::RerollRule.new(6, :<=, :reroll_add)], 4.2],
               [8, [GamesDice::RerollRule.new(1, :>=, :reroll_use_best)], 5.0],
               [4, [GamesDice::RerollRule.new(1, :>=, :reroll_replace, 1)], 2.875]]
      cases.each do |sides, rerolls, expected|
        die = described_class.new(sides, rerolls: rerolls)
        expect(die.probabilities.expected).to be_within(1e-10).of(expected)
      end
    end

    it 'calculate probabilities of each possible result' do
      cases = [[6, [GamesDice::RerollRule.new(7, :>, :reroll_add, 1)], { 11 => 2 / 36.0, 8 => 5 / 36.0 }],
               [10, [GamesDice::RerollRule.new(10, :<=, :reroll_add)],
                { 8 => 0.1, 10 => nil, 13 => 0.01, 27 => 0.001 }],
               [6, [GamesDice::RerollRule.new(1, :>=, :reroll_replace, 1)], { 1 => 1 / 36.0, 2 => 7 / 36.0 }]]
      cases.each do |sides, rerolls, expected|
        probabilities = described_class.new(sides, rerolls: rerolls).probabilities.to_h
        expect_probability_values(probabilities, expected)
      end
    end

    it 'calculate aggregate probabilities' do
      die = described_class.new(6, rerolls: [GamesDice::RerollRule.new(7, :>, :reroll_add, 1)])
      probs = die.probabilities
      expected = { p_gt: { 7 => 15 / 36.0, -10 => 1.0, 12 => 0.0 },
                   p_ge: { 7 => 21 / 36.0, 2 => 1.0, 15 => 0.0 },
                   p_lt: { 7 => 15 / 36.0, -10 => 0.0, 13 => 1.0 },
                   p_le: { 7 => 21 / 36.0, 1 => 0.0, 12 => 1.0 } }
      expect_aggregate_probabilities(probs, expected)
    end
  end

  describe 'with maps' do
    it 'calculate correct minimum and maximum results' do
      die = described_class.new(10, maps: [GamesDice::MapRule.new(7, :<=, 1, 'S')])
      expect(die.min).to be 0
      expect(die.max).to be 1
    end

    it 'simulate a d10 that scores 1 for success on a value of 7 or more' do
      die = described_class.new(10, maps: [[7, :<=, 1, 'S']])
      [0, 0, 1, 0, 1, 1, 0, 1].each do |expected|
        expect(die.roll.value).to eql expected
        expect(die.result.value).to eql expected
      end
    end

    it 'label the mappings applied with the provided names' do
      die = described_class.new(10, maps: [[7, :<=, 1, 'S'], [1, :>=, -1, 'F']])
      ['5', '4', '10 S', '4', '7 S', '8 S', '1 F', '9 S'].each do |expected|
        die.roll
        expect(die.explain_result).to eql expected
      end
    end

    it 'calculate an expected result' do
      die = described_class.new(10,
                                maps: [GamesDice::MapRule.new(7, :<=, 1, 'S'),
                                       GamesDice::MapRule.new(1, :>=, -1, 'F')])
      expect(die.probabilities.expected).to be_within(1e-10).of 0.3
    end

    it 'calculate probabilities of each possible result' do
      die = described_class.new(10,
                                maps: [GamesDice::MapRule.new(7, :<=, 1, 'S'),
                                       GamesDice::MapRule.new(1, :>=, -1, 'F')])
      expect_probability_values(die.probabilities.to_h, { 1 => 0.4, 0 => 0.5, -1 => 0.1 })
    end

    it 'calculate aggregate probabilities' do
      die = described_class.new(10,
                                maps: [GamesDice::MapRule.new(7, :<=, 1, 'S'),
                                       GamesDice::MapRule.new(1, :>=, -1, 'F')])
      probs = die.probabilities
      expected = { p_gt: { -2 => 1.0, -1 => 0.9, 1 => 0.0 }, p_ge: { 1 => 0.4, -1 => 1.0, 2 => 0.0 },
                   p_lt: { 1 => 0.6, -1 => 0.0, 2 => 1.0 }, p_le: { -1 => 0.1, -2 => 0.0, 1 => 1.0 } }
      expect_aggregate_probabilities(probs, expected)
    end
  end

  describe 'with rerolls and maps together' do
    let(:die) do
      described_class.new(6,
                          rerolls: [[6, :<=, :reroll_add]],
                          maps: [GamesDice::MapRule.new(9, :<=, 1, 'Success')])
    end

    it 'calculate correct minimum and maximum results' do
      expect(die.min).to be 0
      expect(die.max).to be 1
    end

    it 'calculate an expected result' do
      expect(die.probabilities.expected).to be_within(1e-10).of 4 / 36.0
    end

    it 'calculate probabilities of each possible result' do
      expect_probability_values(die.probabilities.to_h, { 1 => 4 / 36.0, 0 => 32 / 36.0 })
    end

    it 'calculate aggregate probabilities' do
      expected = { p_gt: { 0 => 4 / 36.0, -2 => 1.0, 1 => 0.0 }, p_ge: { 1 => 4 / 36.0, -1 => 1.0, 2 => 0.0 },
                   p_lt: { 1 => 32 / 36.0, 0 => 0.0, 2 => 1.0 }, p_le: { 0 => 32 / 36.0, -1 => 0.0, 1 => 1.0 } }
      expect_aggregate_probabilities(die.probabilities, expected)
    end

    it 'apply mapping to final re-rolled result' do
      [0, 1, 0, 0].each do |expected|
        expect(die.roll.value).to eql expected
        expect(die.result.value).to eql expected
      end
    end

    it 'explain how it got each result' do
      ['5', '[6+4] 10 Success', '[6+2] 8', '5'].each do |expected|
        die.roll
        expect(die.explain_result).to eql expected
      end
    end
  end
end
