# frozen_string_literal: true

require 'helpers'

describe GamesDice::Dice, :aggregate_failures do
  describe 'dice scheme' do
    before do
      srand(67_809)
    end

    describe '1d10+2' do
      let(:dice) { described_class.new([{ sides: 10, ndice: 1 }], 2) }

      it 'simulate rolling a ten-sided die, and adding two to each result' do
        [5, 4, 10, 10, 7, 5, 9].each do |expected_total|
          expect(dice.roll).to eql expected_total
          expect(dice.result).to eql expected_total
        end
      end
    end

    describe '2d6+6' do
      let(:dice) { described_class.new([{ sides: 6, ndice: 2 }], 6) }

      it 'simulate rolling two six-sided dice and adding six to the result' do
        [15, 12, 17, 15, 13, 13, 16].each do |expected_total|
          expect(dice.roll).to eql expected_total
          expect(dice.result).to eql expected_total
        end
      end
    end
  end

  it 'explains constant-only recipes' do
    dice = described_class.new([], -3)
    expect(dice.roll).to eq(-3)
    expect(dice.explain_result).to eq('-3')
    expect(dice.probabilities.to_h).to eq(-3 => 1.0)
  end

  it 'explains a single bunch with an offset' do
    dice = described_class.new([{ sides: 6, ndice: 1, prng: TestPRNGMax.new }], 2)
    expect(dice.roll).to eq(8)
    expect(dice.explain_result).to eq('1d6: 6. 6 + 2 = 8')
  end

  describe 'multiple weighted bunch explanations' do
    let(:bunches) do
      [{ sides: 6, ndice: 1, prng: TestPRNGMax.new },
       { sides: 4, ndice: 1, multiplier: -1, prng: TestPRNGMax.new }]
    end

    { 0 => '6 - 4 = 2', 3 => '6 - 4 + 3 = 5', -3 => '6 - 4 - 3 = -1' }.each do |offset, sum|
      it "includes an offset of #{offset}" do
        dice = described_class.new(bunches, offset)
        expect(dice.roll).to eq(2 + offset)
        expect(dice.explain_result).to eq("1d6: 6. 1d4: 4. #{sum}")
      end
    end
  end
end
