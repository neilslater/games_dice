# frozen_string_literal: true

require 'helpers'

describe GamesDice::Bunch, :aggregate_failures do
  let(:prng) { Random.new(1) }

  invalid_counts = [0, -1]
  valid_counts = [1, 3, 4]
  %i[keep_best keep_worst].each do |mode|
    invalid_counts.each do |count|
      it "rejects #{count} keepers in #{mode}" do
        expect { described_class.new(ndice: 3, sides: 6, keep_mode: mode, keep_number: count) }
          .to raise_error(ArgumentError, /:keep_number must be 1 or more/)
      end
    end
    valid_counts.each do |count|
      it "keeps at most the whole bunch for #{count} keepers in #{mode}" do
        bunch = described_class.new(ndice: 3, sides: 1, keep_mode: mode, keep_number: count)
        expect(bunch.roll).to eq([count, 3].min)
        expect(bunch.probabilities.to_h).to eq({ [count, 3].min => 1.0 })
        expect(bunch.explain_result).to be_a(String)
      end
    end
  end

  { keep_best: [10, '1 Jackpot'], keep_worst: [1, '6 Low'] }.each do |mode, (total, kept)|
    it "explains the actual mapped keeper for #{mode}" do
      allow(prng).to receive(:rand).and_return(0, 5)
      bunch = mapped_bunch(mode)
      expect(bunch.roll).to eq(total)
      expect(bunch.explain_result).to include("Keep: #{kept}. Successes: #{total}")
    end
  end

  it 'shares its truncation budget across all rolled dice even when only one is kept' do
    bunch = described_class.new(ndice: 20, sides: 2, rerolls: [[2, :==, :reroll_add]], keep_mode: :keep_best)
    expect(bunch.probabilities.to_h).to be_valid_distribution
    expect(bunch.instance_variable_get(:@probability_error)).to be <= 1e-10
  end

  def mapped_bunch(mode)
    described_class.new(ndice: 2, sides: 6, prng: prng, keep_mode: mode,
                        maps: [[1, :==, 10, 'Jackpot'], [2, :<=, 1, 'Low']])
  end
end
