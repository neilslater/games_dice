# frozen_string_literal: true

require 'helpers'

describe GamesDice::ComplexDie, :aggregate_failures do
  def exploding(sides, limit = 1000)
    described_class.new(sides, rerolls: [[sides, :==, :reroll_add, limit]])
  end

  [2, 3, 6, 10].each do |sides|
    it "bounds the omitted mass for an exploding d#{sides}" do
      die = exploding(sides)
      probabilities = die.probabilities
      expect(probabilities.p_eql(1)).to be_within(1e-10).of(1.0 / sides)
      expect(probabilities.to_h.keys).not_to include(sides)
      expect(die.probabilities_complete).to be(false)
    end
  end

  it 'treats terminal branches at the old depth cutoff as complete' do
    die = exploding(2, 19)
    expect(die.probabilities.p_eql(40)).to eq(2.0**-20)
    expect(die.probabilities_complete).to be(true)
  end

  it 'calculates a deterministic singleton without enumerating its roll history' do
    die = exploding(1, 1_000_000)
    expect(die.probabilities.to_h).to eq({ 1_000_001 => 1.0 })
    expect(die.probabilities_complete).to be(true)
    expect(die).to have_attributes(min: 1_000_001, max: 1_000_001)
  end

  it 'keeps deterministic additions exact for nonmatching and nonpositive rules' do
    [-1, 0].each { |limit| expect(exploding(1, limit).probabilities.to_h).to eq({ 1 => 1.0 }) }
    expect(described_class.new(1, rerolls: [[2, :==, :reroll_add]]).probabilities.to_h).to eq({ 1 => 1.0 })
  end

  it 'maps an exact singleton after completing its additive rule' do
    die = described_class.new(1, rerolls: [[1, :==, :reroll_add]], maps: [[1001, :==, 7]])
    expect(die.probabilities.to_h).to eq({ 7 => 1.0 })
  end

  it 'uses the finite replacement formula for more than one triggering face' do
    die = described_class.new(6, rerolls: [[1..2, :cover?, :reroll_replace, 3]])
    probabilities = die.probabilities
    expect(probabilities.p_eql(1)).to be_within(1e-15).of(Rational(8, 1296).to_f)
    expect(probabilities.p_eql(6)).to be_within(1e-15).of(Rational(320, 1296).to_f)
    expect(die.probabilities_complete).to be(true)
  end

  [[0, :>=, 1000], [6, :>=, 1000], [1, :==, 0], [1, :==, -3]].each do |trigger, op, limit|
    it "keeps replacement edge case #{[trigger, op, limit]} exactly uniform" do
      die = described_class.new(6, rerolls: [[trigger, op, :reroll_replace, limit]])
      expect_fair_distribution(die.probabilities.to_h, 6)
      expect(die.probabilities_complete).to be(true)
    end
  end

  it 'refuses a branching recipe at the depth limit and leaves no partial distribution' do
    die = described_class.new(4, rerolls: [[3, :<=, :reroll_add]])
    expect { die.probabilities }.to raise_error(GamesDice::ProbabilityLimitError, /truncation error bound/)
    expect(die.probabilities_complete).to be_nil
    expect(die).to have_attributes(min: 1, max: 4004)
  end

  it 'refuses excessive work for the open-ended percentile example' do
    die = described_class.new(100, rerolls: [[96, :<=, :reroll_add]])
    expect { die.probabilities }.to raise_error(GamesDice::ProbabilityLimitError, /work limit/)
    expect(die).to have_attributes(min: 1, max: 100_100)
  end

  it 'bounds subtracting recipes even when their distribution is refused' do
    die = described_class.new(4, rerolls: [[3, :<=, :reroll_add], [1, :==, :reroll_subtract]])
    expect { die.probabilities }.to raise_error(GamesDice::ProbabilityLimitError)
    expect(die).to have_attributes(min: -4008, max: 4008)
  end

  it 'encloses every ordinary mapped value when the distribution is refused' do
    die = described_class.new(4, rerolls: [[3, :<=, :reroll_add]], maps: [[1, :==, -4], [2, :<=, 7]])
    expect(die).to have_attributes(min: -4, max: 7)
  end

  it 'refuses unprovable bounds for custom numeric mappings' do
    die = described_class.new(4, rerolls: [[3, :<=, :reroll_add]], maps: [[->(value) { value * 2 }, :call]])
    expect { die.min }.to raise_error(GamesDice::ProbabilityLimitError, /Cannot establish finite dice bounds/)
  end

  it 'enumerates custom predicates rather than assuming they return booleans' do
    die = described_class.new(2, rerolls: [[->(face) { face == 1 }, :call, :reroll_replace, 1]])
    expect(die.probabilities.to_h).to eq({ 1 => 0.25, 2 => 0.75 })
  end

  it 'propagates exceptions raised by custom callbacks' do
    die = described_class.new(2, maps: [[->(_) { raise RangeError, 'custom failure' }, :call]])
    expect { die.min }.to raise_error(RangeError, 'custom failure')
  end

  it 'reuses a tight cache for loose requests and recomputes for tighter budgets' do
    die = exploding(2)
    loose = die.probabilities
    tight = die.__send__(:probabilities_for_budget, 1e-14)
    expect(tight).not_to equal(loose)
    expect(die.probabilities).to equal(tight)
  end

  it 'does not return a loose cache when a tighter request fails' do
    die = exploding(2)
    loose = die.probabilities
    expect { die.__send__(:probabilities_for_budget, 1e-30) }.to raise_error(GamesDice::ProbabilityLimitError)
    expect(die.probabilities_complete).to be_nil
    expect(die.probabilities).to equal(loose)
  end

  it 'counts mapping predicates towards the work limit' do
    stub_const('GamesDice::ProbabilityBudget::MAX_PREDICATES', 3)
    die = described_class.new(6, maps: [[1, :==, 1]])
    expect { die.probabilities }.to raise_error(GamesDice::ProbabilityLimitError, /work limit/)
  end
end
