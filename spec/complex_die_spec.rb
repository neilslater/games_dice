require 'games_dice'

# Test helper class, a stub of a PRNG
class TestPRNG
  def initialize
    @numbers = [0.123,0.234,0.345,0.999,0.876,0.765,0.543,0.111,0.333,0.777]
  end
  def rand(n)
    Integer( n * @numbers.pop )
  end
end

describe GamesDice::ComplexDie do

  before do
    # Set state of default PRNG
    srand(4567)
  end

  it "should represent a basic die as an object" do
    die = GamesDice::ComplexDie.new(6)
    die.min.should == 1
    die.max.should == 6
    die.sides.should == 6
  end

  it "should return results based on Ruby's internal rand() by default" do
    die = GamesDice::ComplexDie.new(10)
    [5,4,10,4,7,8,1,9].each do |expected|
      die.roll.should == expected
      die.result.should == expected
    end
  end

  it "should use any object with a rand(Integer) method" do
    prng = TestPRNG.new()
    die = GamesDice::ComplexDie.new(20, :prng => prng)
    [16,7,3,11,16,18,20,7].each do |expected|
      die.roll.should == expected
      die.result.should == expected
    end
  end

  it "should optionally accept a rerolls param" do
    GamesDice::ComplexDie.new( 10, :rerolls => [] )
    GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(6, :<=, :reroll_add)] )
    GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(6, :<=, :reroll_add),GamesDice::RerollRule.new(1, :>=, :reroll_subtract)] )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => 7 )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => ['hello'] )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls =>  [GamesDice::RerollRule.new(6, :<=, :reroll_add), :reroll_add] )
    end.should raise_error( TypeError )
  end

  it "should optionally accept a maps param" do
    GamesDice::ComplexDie.new( 10, :maps => [] )
    GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1)] )
    GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1), GamesDice::MapRule.new(1, :>, -1) ] )

    lambda do
      GamesDice::ComplexDie.new( 10, :maps => 7 )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :maps => ['hello'] )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :maps =>  [GamesDice::MapRule.new(7, :<=, 1),GamesDice::RerollRule.new(6, :<=, :reroll_add)] )
    end.should raise_error( TypeError )
  end

  describe "with rerolls" do
    it "should calculate correct minimum and maximum results" do
      die = GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add, 3)] )
      die.min.should == 1
      die.max.should == 40

      die = GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_subtract)] )
      die.min.should == -9
      die.max.should == 10

      die = GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add)] )
      die.min.should == 1
      die.max.should == 10_010
    end

    it "should simulate a d10 that rerolls and adds on a result of 10" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add)] )
      [5,4,14,7,8,1,9].each do |expected|
        die.roll.should == expected
        die.result.should == expected
      end
    end

    it "should explain how it got results outside range 1 to 10 on a d10" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add),GamesDice::RerollRule.new(1, :>=, :reroll_subtract)] )
      ["5","4","[10+4] 14","7","8","[1-9] -8"].each do |expected|
        die.roll
        die.explain_result.should == expected
      end
    end

    it "should calculate an expected result" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add),GamesDice::RerollRule.new(1, :>=, :reroll_subtract)] )
      die.expected_result.should be_within(1e-10).of 5.5

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(1, :<=, :reroll_use_best, 1)] )
      die.expected_result.should be_within(1e-10).of 7.15

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(1, :<=, :reroll_use_worst, 2)] )
      die.expected_result.should be_within(1e-10).of 3.025

      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(6, :<=, :reroll_add)] )
      die.expected_result.should be_within(1e-10).of 4.2

      die = GamesDice::ComplexDie.new(8, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_use_best)] )
      die.expected_result.should be_within(1e-10).of 5.0

      die = GamesDice::ComplexDie.new(4, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_replace, 1)] )
      die.expected_result.should be_within(1e-10).of 2.875
    end

    it "should calculate probabilities of each possible result" do
      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(7, :>, :reroll_add, 1)] )
      die.probabilities[11].should be_within(1e-10).of 2/36.0
      die.probabilities[8].should be_within(1e-10).of 5/36.0
      die.probabilities.values.inject(:+).should be_within(1e-9).of 1.0

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add)] )
      die.probabilities[8].should be_within(1e-10).of 0.1
      die.probabilities[10].should be_false
      die.probabilities[13].should be_within(1e-10).of 0.01
      die.probabilities[27].should be_within(1e-10).of 0.001
      die.probabilities.values.inject(:+).should be_within(1e-9).of 1.0

      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_replace, 1)] )
      die.probabilities[1].should be_within(1e-10).of 1/36.0
      die.probabilities[2].should be_within(1e-10).of 7/36.0
      die.probabilities.values.inject(:+).should be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(7, :>, :reroll_add, 1)] )
      die.probability_gt(7).should be_within(1e-10).of 15/36.0
      die.probability_gt(-10).should == 1.0
      die.probability_gt(12).should == 0.0

      die.probability_ge(7).should be_within(1e-10).of 21/36.0
      die.probability_ge(2).should == 1.0
      die.probability_ge(15).should == 0.0

      die.probability_lt(7).should be_within(1e-10).of 15/36.0
      die.probability_lt(-10).should == 0.0
      die.probability_lt(13).should == 1.0

      die.probability_le(7).should be_within(1e-10).of 21/36.0
      die.probability_le(1).should == 0.0
      die.probability_le(12).should == 1.0
    end
  end

  describe "with maps" do
    it "should calculate correct minimum and maximum results" do
      die = GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S')] )
      die.min.should == 0
      die.max.should == 1
    end

    it "should simulate a d10 that scores 'S' for success on a value of 7 or more" do
      die = GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S')] )
      [0,0,1,0,1,1,0,1].each do |expected|
        die.roll.should == expected
        die.result.should == expected
      end
    end

    it "should label the mappings applied with the provided names" do
      die = GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      ["5", "4", "10 S", "4", "7 S", "8 S", "1 F", "9 S"].each do |expected|
        die.roll
        die.explain_result.should == expected
      end
    end

    it "should calculate an expected result" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      die.expected_result.should be_within(1e-10).of 0.3
    end

    it "should calculate probabilities of each possible result" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      die.probabilities[1].should be_within(1e-10).of 0.4
      die.probabilities[0].should be_within(1e-10).of 0.5
      die.probabilities[-1].should be_within(1e-10).of 0.1
      die.probabilities.values.inject(:+).should be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      die.probability_gt(-1).should be_within(1e-10).of 0.9
      die.probability_gt(-2).should == 1.0
      die.probability_gt(1).should == 0.0

      die.probability_ge(1).should be_within(1e-10).of 0.4
      die.probability_ge(-1).should == 1.0
      die.probability_ge(2).should == 0.0

      die.probability_lt(1).should be_within(1e-10).of 0.6
      die.probability_lt(-1).should == 0.0
      die.probability_lt(2).should == 1.0

      die.probability_le(-1).should be_within(1e-10).of 0.1
      die.probability_le(-2).should == 0.0
      die.probability_le(1).should == 1.0
    end
  end

  describe "with rerolls and maps" do
    before do
      @die = GamesDice::ComplexDie.new( 6,
        :rerolls => [GamesDice::RerollRule.new(6, :<=, :reroll_add)],
        :maps => [GamesDice::MapRule.new(9, :<=, 1, 'Success')]
        )
    end

    it "should calculate correct minimum and maximum results" do
      @die.min.should == 0
      @die.max.should == 1
    end

    it "should calculate an expected result" do
      @die.expected_result.should be_within(1e-10).of 4/36.0
    end

    it "should calculate probabilities of each possible result" do
      @die.probabilities[1].should be_within(1e-10).of 4/36.0
      @die.probabilities[0].should be_within(1e-10).of 32/36.0
      @die.probabilities.values.inject(:+).should be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      @die.probability_gt(0).should be_within(1e-10).of 4/36.0
      @die.probability_gt(-2).should == 1.0
      @die.probability_gt(1).should == 0.0

      @die.probability_ge(1).should be_within(1e-10).of 4/36.0
      @die.probability_ge(-1).should == 1.0
      @die.probability_ge(2).should == 0.0

      @die.probability_lt(1).should be_within(1e-10).of 32/36.0
      @die.probability_lt(0).should == 0.0
      @die.probability_lt(2).should == 1.0

      @die.probability_le(0).should be_within(1e-10).of 32/36.0
      @die.probability_le(-1).should == 0.0
      @die.probability_le(1).should == 1.0
    end

    it "should apply mapping to final re-rolled result" do
      [0,1,0,0].each do |expected|
        @die.roll.should == expected
        @die.result.should == expected
      end
    end

    it "should explain how it got each result" do
      ["5", "[6+4] 10 Success", "[6+2] 8", "5"].each do |expected|
        @die.roll
        @die.explain_result.should == expected
      end
    end
  end

end