require 'games_dice'
# This spec demonstrates that documentation from the README.md works as intended

# Test helper class, a stub of a PRNG
class TestPRNG
  def initialize
    @numbers = [0.123,0.234,0.345,0.999,0.876,0.765,0.543,0.111,0.333,0.777]
  end
  def rand(n)
    Integer( n * @numbers.pop )
  end
end

describe GamesDice do

  describe '#create' do
    it "converts a string such as '3d6+6' into a GamesDice::Dice object" do
      d = GamesDice.create '3d6+6'
      d.is_a?( GamesDice::Dice ).should be_true
    end

    it "takes a parameter 'dice_description', which is a string such as '3d6' or '2d4-1'" do
      d = GamesDice.create '3d6'
      d.is_a?( GamesDice::Dice ).should be_true
      d = GamesDice.create '2d4-1'
      d.is_a?( GamesDice::Dice ).should be_true
    end

    it "takes an optional parameter 'prng', which if provided it should be an object that has a method 'rand( integer )'" do
      prng = TestPRNG.new
      d = GamesDice.create '3d6', prng
      d.is_a?( GamesDice::Dice ).should be_true
    end
  end # describe '#create'

end # describe GamesDice

describe GamesDice::Dice do

  before :each do
    srand(67809)
  end

  let(:dice) { GamesDice.create '3d6'}

  describe "#roll" do
    it "simulates rolling the dice as they were described in the constructor" do
      expected_results = [11,15,11,12,12,9]
      expected_results.each do |expected|
        dice.roll.should == expected
      end
    end
  end

  describe "#result" do
    it "returns the value from the last call to roll" do
      expected_results = [11,15,11,12,12,9]
      expected_results.each do |expected|
        dice.roll
        dice.result.should == expected
      end
    end

    it "will be nil if no roll has been made yet" do
      dice.result.should be_nil
    end
  end

  describe "#max" do
    it "returns the maximum possible value from a roll of the dice" do
      dice.max.should == 18
    end
  end

  describe "#min" do
    it "returns the minimum possible value from a roll of the dice" do
      dice.min.should == 3
    end
  end

  describe "#minmax" do
    it "returns an array [ dice.min, dice.max ]" do
      dice.minmax.should == [3,18]
    end
  end

  describe "#probabilities" do
    it "calculates probability distribution for the dice" do
      pd = dice.probabilities
      pd.is_a?( GamesDice::Probabilities ).should be_true
      pd.p_eql( 3).should be_within(1e-10).of 1.0/216
      pd.p_eql( 11 ).should be_within(1e-10).of 27.0/216
    end
  end

end # describe GamesDice::Dice
