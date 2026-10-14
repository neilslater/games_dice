# frozen_string_literal: true

require 'helpers'

describe GamesDice::Dice, :aggregate_failures do
  let(:prng) { Random.new(1) }

  { '-1d6+2' => [-4, 1], '2d6-1d4' => [-2, 11], '-2d6' => [-12, -2] }.each do |notation, bounds|
    it "reverses negative terms in bounds for #{notation}" do
      dice = GamesDice.create(notation)
      expect(dice.minmax).to eq(bounds)
      expect(dice.probabilities).to have_attributes(min: bounds.first, max: bounds.last)
    end
  end

  it 'skips zero-weight components that cannot calculate a distribution' do
    dice = described_class.new([{ ndice: 1, sides: 4, rerolls: [[3, :<=, :reroll_add]], multiplier: 0 }], 5)
    expect(dice.minmax).to eq([5, 5])
    expect(dice.probabilities.to_h).to eq({ 5 => 1.0 })
  end

  { '-1d6+2' => '1d6: 1. -1 + 2 = 1', '-1d6' => '1d6: 1. -1 = -1' }.each do |notation, explanation|
    it "explains the weighted result for #{notation}" do
      allow(prng).to receive(:rand).and_return(0)
      dice = GamesDice.create(notation, prng)
      dice.roll
      expect(dice.explain_result).to eq(explanation)
    end
  end

  it 'shares one truncation budget across repeated dice and negatively weighted bunches' do
    dice = GamesDice.create('3d2x-2d2x')
    expect(dice.probabilities.to_h).to be_valid_distribution
    expect(dice.instance_variable_get(:@probability_error)).to be <= 1e-10
  end

  it 'preserves the default repeated shorthand reroll' do
    allow(prng).to receive(:rand).and_return(0, 0, 4)
    dice = GamesDice.create('1d6r1', prng)
    expect(dice.roll).to eq(5)
    expect(dice.bunches.first.result_details.first.rolls).to eq([1, 1, 5])
  end

  it 'supports an explicit single replacement reroll' do
    allow(prng).to receive(:rand).and_return(0, 0, 4)
    dice = GamesDice.create('1d6r:1,replace,1.', prng)
    expect(dice.roll).to eq(1)
    expect(dice.bunches.first.result_details.first.rolls).to eq([1, 1])
  end
end
