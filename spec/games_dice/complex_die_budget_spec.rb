# frozen_string_literal: true

require 'helpers'

describe GamesDice::ComplexDie, :aggregate_failures do
  def observed_omissions(counts)
    allow(GamesDice::ProbabilityBudget).to receive(:new).and_wrap_original do |constructor, *arguments|
      constructor.call(*arguments).tap do |budget|
        allow(budget).to receive(:omit?).and_wrap_original do |original, depth, probability|
          original.call(depth, probability).tap { |omitted| counts[depth] += 1 if omitted }
        end
      end
    end
  end

  [1, 10, 1000, 1_000_000].each do |count|
    it "certifies the exact omitted mass when sharing a budget across #{count} dice" do
      counts = Hash.new(0)
      observed_omissions(counts)
      die = described_class.new(2, rerolls: [[2, :==, :reroll_add]])
      die.__send__(:probabilities_for_budget, GamesDice::ProbabilityBudget.share(1e-10.prev_float, count))
      expect_certified_omission(die, counts, count)
    end
  end

  def expect_certified_omission(die, counts, count)
    exact = counts.sum { |depth, branches| Rational(branches, 2**depth) }
    expect(exact).to be <= die.instance_variable_get(:@probability_error).to_r
    expect(count * exact).to be <= Rational(1, 10**10)
  end

  it 'handles near-certain replacement triggers without traversing the reroll limit' do
    die = described_class.new(100_000, rerolls: [[99_999, :>=, :reroll_replace, 1_000_000]])
    expect(die.probabilities.to_h).to be_valid_distribution
    expect(die.probabilities.p_eql(100_000)).to be_within(1e-12).of(1 - ((0.99999**1_000_000) * 0.99999))
    expect(die.probabilities_complete).to be(true)
  end

  it 'provides cheap exact bounds even when a deterministic outcome exceeds native storage' do
    die = described_class.new(1, rerolls: [[1, :==, :reroll_add, 2**31]])
    expect(die).to have_attributes(min: (2**31) + 1, max: (2**31) + 1)
    expect { die.probabilities }.to raise_error(RangeError)
    expect(die.probabilities_complete).to be_nil
  end

  it 'preserves a previous roll while recomputing a tighter probability certificate' do
    die = described_class.new(2, rerolls: [[2, :==, :reroll_add]])
    previous = die.roll
    die.probabilities
    die.__send__(:probabilities_for_budget, 1e-14)
    expect(die.result).to equal(previous)
  end

  it 'treats absent numerical certificates as requiring recomputation after restoration' do
    die = described_class.new(2, rerolls: [[2, :==, :reroll_add]])
    die.probabilities
    die.remove_instance_variable(:@probability_error)
    expect(marshal_round_trip(die).probabilities.to_h).to be_valid_distribution
  end
end
