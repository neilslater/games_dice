require 'helpers'

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
    GamesDice::ComplexDie.new( 10, :rerolls => [[6, :<=, :reroll_add]] )
    GamesDice::ComplexDie.new( 10, :rerolls => [[6, :<=, :reroll_add],[1, :>=, :reroll_subtract]] )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => 7 )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => ['hello'] )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls =>  [GamesDice::RerollRule.new(6, :<=, :reroll_add), :reroll_add] )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => [7] )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => [['hello']] )
    end.should raise_error( ArgumentError )

    lambda do
      GamesDice::ComplexDie.new( 10, :rerolls =>  [ [6, :<=, :reroll_add ], :reroll_add] )
    end.should raise_error( TypeError )

  end

  it "should optionally accept a maps param" do
    GamesDice::ComplexDie.new( 10, :maps => [] )
    GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1)] )
    GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1), GamesDice::MapRule.new(1, :>, -1) ] )
    GamesDice::ComplexDie.new( 10, :maps => [ [7, :<=, 1] ] )
    GamesDice::ComplexDie.new( 10, :maps => [ [7, :<=, 1], [1, :>, -1] ] )

    lambda do
      GamesDice::ComplexDie.new( 10, :maps => 7 )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :maps => [7] )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :maps => [ [7] ] )
    end.should raise_error( ArgumentError )

    lambda do
      GamesDice::ComplexDie.new( 10, :maps => ['hello'] )
    end.should raise_error( TypeError )

    lambda do
      GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1),GamesDice::RerollRule.new(6, :<=, :reroll_add)] )
    end.should raise_error( TypeError )
  end

  describe "with rerolls" do
    it "should calculate correct minimum and maximum results" do
      die = GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add, 3)] )
      die.min.should == 1
      die.max.should == 40

      die = GamesDice::ComplexDie.new( 10, :rerolls => [[1, :>=, :reroll_subtract]] )
      die.min.should == -9
      die.max.should == 10

      die = GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add)] )
      die.min.should == 1
      die.max.should == 10_010
    end

    it "should simulate a d10 that rerolls and adds on a result of 10" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [[10, :<=, :reroll_add]] )
      [5,4,14,7,8,1,9].each do |expected|
        die.roll.should == expected
        die.result.should == expected
      end
    end

    it "should explain how it got results outside range 1 to 10 on a d10" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [[10, :<=, :reroll_add],[1, :>=, :reroll_subtract]] )
      ["5","4","[10+4] 14","7","8","[1-9] -8"].each do |expected|
        die.roll
        die.explain_result.should == expected
      end
    end

    it "should calculate an expected result" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [[10, :<=, :reroll_add],[1, :>=, :reroll_subtract]] )
      die.probabilities.expected.should be_within(1e-10).of 5.5

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(1, :<=, :reroll_use_best, 1)] )
      die.probabilities.expected.should be_within(1e-10).of 7.15

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(1, :<=, :reroll_use_worst, 2)] )
      die.probabilities.expected.should be_within(1e-10).of 3.025

      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(6, :<=, :reroll_add)] )
      die.probabilities.expected.should be_within(1e-10).of 4.2

      die = GamesDice::ComplexDie.new(8, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_use_best)] )
      die.probabilities.expected.should be_within(1e-10).of 5.0

      die = GamesDice::ComplexDie.new(4, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_replace, 1)] )
      die.probabilities.expected.should be_within(1e-10).of 2.875
    end

    it "should calculate probabilities of each possible result" do
      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(7, :>, :reroll_add, 1)] )
      probs = die.probabilities.to_h
      probs[11].should be_within(1e-10).of 2/36.0
      probs[8].should be_within(1e-10).of 5/36.0
      probs.values.inject(:+).should be_within(1e-9).of 1.0

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add)] )
      probs = die.probabilities.to_h
      probs[8].should be_within(1e-10).of 0.1
      probs[10].should be_false
      probs[13].should be_within(1e-10).of 0.01
      probs[27].should be_within(1e-10).of 0.001
      probs.values.inject(:+).should be_within(1e-9).of 1.0

      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_replace, 1)] )
      probs = die.probabilities.to_h
      probs[1].should be_within(1e-10).of 1/36.0
      probs[2].should be_within(1e-10).of 7/36.0
      probs.values.inject(:+).should be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(7, :>, :reroll_add, 1)] )
      probs = die.probabilities
      probs.p_gt(7).should be_within(1e-10).of 15/36.0
      probs.p_gt(-10).should == 1.0
      probs.p_gt(12).should == 0.0

      probs.p_ge(7).should be_within(1e-10).of 21/36.0
      probs.p_ge(2).should == 1.0
      probs.p_ge(15).should == 0.0

      probs.p_lt(7).should be_within(1e-10).of 15/36.0
      probs.p_lt(-10).should == 0.0
      probs.p_lt(13).should == 1.0

      probs.p_le(7).should be_within(1e-10).of 21/36.0
      probs.p_le(1).should == 0.0
      probs.p_le(12).should == 1.0
    end
  end

  describe "with maps" do
    it "should calculate correct minimum and maximum results" do
      die = GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S')] )
      die.min.should == 0
      die.max.should == 1
    end

    it "should simulate a d10 that scores 1 for success on a value of 7 or more" do
      die = GamesDice::ComplexDie.new( 10, :maps => [ [ 7, :<=, 1, 'S' ] ] )
      [0,0,1,0,1,1,0,1].each do |expected|
        die.roll.should == expected
        die.result.should == expected
      end
    end

    it "should label the mappings applied with the provided names" do
      die = GamesDice::ComplexDie.new( 10, :maps => [ [7, :<=, 1, 'S'], [1, :>=, -1, 'F'] ] )
      ["5", "4", "10 S", "4", "7 S", "8 S", "1 F", "9 S"].each do |expected|
        die.roll
        die.explain_result.should == expected
      end
    end

    it "should calculate an expected result" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      die.probabilities.expected.should be_within(1e-10).of 0.3
    end

    it "should calculate probabilities of each possible result" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      probs_hash = die.probabilities.to_h
      probs_hash[1].should be_within(1e-10).of 0.4
      probs_hash[0].should be_within(1e-10).of 0.5
      probs_hash[-1].should be_within(1e-10).of 0.1
      probs_hash.values.inject(:+).should be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      probs = die.probabilities
      probs.p_gt(-2).should == 1.0
      probs.p_gt(-1).should be_within(1e-10).of 0.9
      probs.p_gt(1).should == 0.0

      probs.p_ge(1).should be_within(1e-10).of 0.4
      probs.p_ge(-1).should == 1.0
      probs.p_ge(2).should == 0.0

      probs.p_lt(1).should be_within(1e-10).of 0.6
      probs.p_lt(-1).should == 0.0
      probs.p_lt(2).should == 1.0

      probs.p_le(-1).should be_within(1e-10).of 0.1
      probs.p_le(-2).should == 0.0
      probs.p_le(1).should == 1.0
    end
  end

  describe "with rerolls and maps together" do
    before do
      @die = GamesDice::ComplexDie.new( 6,
        :rerolls => [[6, :<=, :reroll_add]],
        :maps => [GamesDice::MapRule.new(9, :<=, 1, 'Success')]
        )
    end

    it "should calculate correct minimum and maximum results" do
      @die.min.should == 0
      @die.max.should == 1
    end

    it "should calculate an expected result" do
      @die.probabilities.expected.should be_within(1e-10).of 4/36.0
    end

    it "should calculate probabilities of each possible result" do
      probs_hash = @die.probabilities.to_h
      probs_hash[1].should be_within(1e-10).of 4/36.0
      probs_hash[0].should be_within(1e-10).of 32/36.0
      probs_hash.values.inject(:+).should be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      probs = @die.probabilities

      probs.p_gt(0).should be_within(1e-10).of 4/36.0
      probs.p_gt(-2).should == 1.0
      probs.p_gt(1).should == 0.0

      probs.p_ge(1).should be_within(1e-10).of 4/36.0
      probs.p_ge(-1).should == 1.0
      probs.p_ge(2).should == 0.0

      probs.p_lt(1).should be_within(1e-10).of 32/36.0
      probs.p_lt(0).should == 0.0
      probs.p_lt(2).should == 1.0

      probs.p_le(0).should be_within(1e-10).of 32/36.0
      probs.p_le(-1).should == 0.0
      probs.p_le(1).should == 1.0
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
  end # describe "with rerolls and maps"
end # describe GamesDice::ComplexDie