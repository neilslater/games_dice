# frozen_string_literal: true

require 'helpers'

describe GamesDice::Die do
  before do
    # Set state of default PRNG
    srand(4567)
  end

  describe '#new' do
    it 'return an object that represents e.g. a six-sided die' do
      die = described_class.new(6)
      expect(die.min).to be 1
      expect(die.max).to be 6
      expect(die.sides).to be 6
    end

    it 'accept any object with a rand(Integer) method as the second param' do
      prng = TestPRNG.new
      die = described_class.new(20, prng)
      [16, 7, 3, 11, 16, 18, 20, 7].each do |expected|
        expect(die.roll).to eql expected
        expect(die.result).to eql expected
      end
    end
  end

  describe '#roll and #result' do
    it "return results based on Ruby's internal rand() by default" do
      die = described_class.new(10)
      [5, 4, 10, 4, 7, 8, 1, 9].each do |expected|
        expect(die.roll).to eql expected
        expect(die.result).to eql expected
      end
    end
  end

  describe '#min and #max' do
    it 'calculate correct min, max' do
      die = described_class.new(20)
      expect(die.min).to be 1
      expect(die.max).to be 20
    end
  end

  describe '#probabilities' do
    it "return the die's probability distribution as a GamesDice::Probabilities object" do
      die = described_class.new(6)
      probs = die.probabilities
      expect(probs).to be_a GamesDice::Probabilities

      expect(probs.to_h).to be_valid_distribution

      expect(probs.p_eql(1)).to be_within(1e-10).of 1 / 6.0
      expect(probs.p_eql(2)).to be_within(1e-10).of 1 / 6.0
      expect(probs.p_eql(3)).to be_within(1e-10).of 1 / 6.0
      expect(probs.p_eql(4)).to be_within(1e-10).of 1 / 6.0
      expect(probs.p_eql(5)).to be_within(1e-10).of 1 / 6.0
      expect(probs.p_eql(6)).to be_within(1e-10).of 1 / 6.0

      expect(probs.expected).to be_within(1e-10).of 3.5
    end
  end

  describe '#all_values' do
    it 'return array with one result value per side' do
      die = described_class.new(8)
      expect(die.all_values).to eql [1, 2, 3, 4, 5, 6, 7, 8]
    end
  end

  describe '#each_value' do
    it 'iterate through all sides of the die' do
      die = described_class.new(10)
      arr = []
      die.each_value { |x| arr << x }
      expect(arr).to eql [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    end
  end
end
