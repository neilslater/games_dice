require 'games_dice/die'

# Test helper class, a stub of a PRNG
class TestPRNG
  def initialize
    # Numbers that I randomly thought up!
    @numbers = [0.123,0.234,0.345,0.999,0.876,0.765,0.543,0.111,0.333,0.777]
  end
  def rand(n)
    Integer( n * @numbers.pop )
  end
end

describe GamesDice::Die do

  before do
    # Set state of default PRNG
    srand(4567)
  end

  describe "#new" do
    it "should return an object that represents e.g. a six-sided die" do
      die = GamesDice::Die.new(6)
      die.min.should == 1
      die.max.should == 6
      die.sides.should == 6
      die.probabilities.should == { 1 => 1.0/6, 2 => 1.0/6, 3 => 1.0/6, 4 => 1.0/6, 5 => 1.0/6, 6 => 1.0/6 }
      die.expected_result.should == 3.5
    end

    it "should accept any object with a rand(Integer) method as the second param" do
      prng = TestPRNG.new()
      die = GamesDice::Die.new(20,prng)
      [16,7,3,11,16,18,20,7].each do |expected|
        die.roll.should == expected
        die.result.should == expected
      end
    end
  end

  describe "#roll and #result" do
    it "should return results based on Ruby's internal rand() by default" do
    die = GamesDice::Die.new(10)
      [5,4,10,4,7,8,1,9].each do |expected|
        die.roll.should == expected
        die.result.should == expected
      end
    end
  end

  describe "#min and #max" do
    it "should calculate correct min, max" do
      die = GamesDice::Die.new(20)
      die.min.should == 1
      die.max.should == 20
    end
  end

  describe "#expected_result" do
    it "should calculate correct weighted mean" do
      die = GamesDice::Die.new(20)
      die.expected_result.should be_within(1e-10).of 10.5
    end
  end

  describe "#probabilities" do
    it "should calculate probabilities accurately" do
      die = GamesDice::Die.new(6)
      die.probabilities[1].should be_within(1e-10).of 1/6.0
      die.probabilities[2].should be_within(1e-10).of 1/6.0
      die.probabilities[3].should be_within(1e-10).of 1/6.0
      die.probabilities[4].should be_within(1e-10).of 1/6.0
      die.probabilities[5].should be_within(1e-10).of 1/6.0
      die.probabilities[6].should be_within(1e-10).of 1/6.0
      die.probabilities.values.inject(:+).should be_within(1e-9).of 1.0

      die.probability_gt(6).should == 0.0
      die.probability_gt(-20).should == 1.0
      die.probability_gt(4).should be_within(1e-10).of 2/6.0

      die.probability_ge(20).should == 0.0
      die.probability_ge(1).should == 1.0
      die.probability_ge(4).should be_within(1e-10).of 0.5

      die.probability_le(6).should == 1.0
      die.probability_le(-3).should == 0.0
      die.probability_le(5).should be_within(1e-10).of 5/6.0

      die.probability_lt(7).should == 1.0
      die.probability_lt(1).should == 0.0
      die.probability_lt(3).should be_within(1e-10).of 2/6.0
    end
  end

end