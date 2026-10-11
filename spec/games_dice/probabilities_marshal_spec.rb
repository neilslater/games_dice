# frozen_string_literal: true

require 'helpers'

describe GamesDice::Probabilities, :aggregate_failures do
  def expect_usable_restoration(original, restored)
    expect(restored.repeat_sum(2).expected).to be_within(1e-10).of(2 * original.expected)
    GC.start
    expect(restored.p_ge(restored.min)).to eq(1.0)
  end

  def restored_dice
    original = GamesDice.create('2d6x.m:>=8,1,Success.+1d4')
    expected = original.probabilities.to_h
    marshal_round_trip(original).tap { |restored| expect(restored.probabilities.to_h).to eq(expected) }
  end

  describe 'current Marshal protocol'  do
    [{ -3 => 0.25, 4 => 0.75 }, { 0 => 1.0 }, (1..6).to_h { |face| [face, 1.0 / 6] }].each do |values|
      it "round trips #{values.inspect} into usable independent native storage" do
        original = described_class.from_h(values)
        restored = marshal_round_trip(original)
        expect(restored.clone.to_h).to eq(values)
        expect_usable_restoration(original, restored)
      end
    end

    it 'round trips dice with cached probabilities and refreshes their mutable recipes' do
      restored = restored_dice
      restored.bunch_multipliers[0] = 0
      expect(restored.probabilities.to_h).to eq(GamesDice.create('1d4').probabilities.to_h)
    end

    it 'rejects invalid payloads without damaging the previous distribution' do
      distribution = described_class.new([1.0], -2)
      [[nil, TypeError], [{}, ArgumentError], [{ 1 => Float::NAN }, ArgumentError]].each do |invalid, error|
        expect { distribution.marshal_load(invalid) }.to raise_error(error)
      end
      expect(distribution.to_h).to eq({ -2 => 1.0 })
    end

    it 'does not expose the obsolete legacy decoder' do
      expect(described_class).not_to respond_to(:_load)
    end
  end
end
