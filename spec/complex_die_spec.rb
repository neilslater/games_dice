require 'helpers'

describe GamesDice::ComplexDie do

  before do
    # Set state of default PRNG
    srand(4567)
  end

  it "should represent a basic die as an object" do
    die = GamesDice::ComplexDie.new(6)
    expect(die.min).to eql 1
    expect(die.max).to eql 6
    expect(die.sides).to eql 6
  end

  it "should return results based on Ruby's internal rand() by default" do
    die = GamesDice::ComplexDie.new(10)
    [5,4,10,4,7,8,1,9].each do |expected|
      expect(die.roll.value).to eql expected
      expect(die.result.value).to eql expected
    end
  end

  it "should use any object with a rand(Integer) method" do
    prng = TestPRNG.new()
    die = GamesDice::ComplexDie.new(20, :prng => prng)
    [16,7,3,11,16,18,20,7].each do |expected|
      expect(die.roll.value).to eql expected
      expect(die.result.value).to eql expected
    end
  end

  it "should optionally accept a rerolls param" do
    GamesDice::ComplexDie.new( 10, :rerolls => [] )
    GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(6, :<=, :reroll_add)] )
    GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(6, :<=, :reroll_add),GamesDice::RerollRule.new(1, :>=, :reroll_subtract)] )
    GamesDice::ComplexDie.new( 10, :rerolls => [[6, :<=, :reroll_add]] )
    GamesDice::ComplexDie.new( 10, :rerolls => [[6, :<=, :reroll_add],[1, :>=, :reroll_subtract]] )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => 7 )
    end).to raise_error( TypeError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => ['hello'] )
    end).to raise_error( TypeError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :rerolls =>  [GamesDice::RerollRule.new(6, :<=, :reroll_add), :reroll_add] )
    end).to raise_error( TypeError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => [7] )
    end).to raise_error( TypeError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :rerolls => [['hello']] )
    end).to raise_error( ArgumentError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :rerolls =>  [ [6, :<=, :reroll_add ], :reroll_add] )
    end).to raise_error( TypeError )

  end

  it "should optionally accept a maps param" do
    GamesDice::ComplexDie.new( 10, :maps => [] )
    GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1)] )
    GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1), GamesDice::MapRule.new(1, :>, -1) ] )
    GamesDice::ComplexDie.new( 10, :maps => [ [7, :<=, 1] ] )
    GamesDice::ComplexDie.new( 10, :maps => [ [7, :<=, 1], [1, :>, -1] ] )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :maps => 7 )
    end).to raise_error( TypeError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :maps => [7] )
    end).to raise_error( TypeError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :maps => [ [7] ] )
    end).to raise_error( ArgumentError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :maps => ['hello'] )
    end).to raise_error( TypeError )

    expect(lambda do
      GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1),GamesDice::RerollRule.new(6, :<=, :reroll_add)] )
    end).to raise_error( TypeError )
  end

  describe "with rerolls" do
    it "should calculate correct minimum and maximum results" do
      die = GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add, 3)] )
      expect(die.min).to eql 1
      expect(die.max).to eql 40

      die = GamesDice::ComplexDie.new( 10, :rerolls => [[1, :>=, :reroll_subtract]] )
      expect(die.min).to eql -9
      expect(die.max).to eql 10

      die = GamesDice::ComplexDie.new( 10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add)] )
      expect(die.min).to eql 1
      expect(die.max).to eql 10_010
    end

    it "should simulate a d10 that rerolls and adds on a result of 10" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [[10, :<=, :reroll_add]] )
      [5,4,14,7,8,1,9].each do |expected|
        expect(die.roll.value).to eql expected
        expect(die.result.value).to eql expected
      end
    end

    it "should explain how it got results outside range 1 to 10 on a d10" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [[10, :<=, :reroll_add],[1, :>=, :reroll_subtract]] )
      ["5","4","[10+4] 14","7","8","[1-9] -8"].each do |expected|
        die.roll
        expect(die.explain_result).to eql expected
      end
    end

    it "should calculate an expected result" do
      die = GamesDice::ComplexDie.new(10, :rerolls => [[10, :<=, :reroll_add],[1, :>=, :reroll_subtract]] )
      expect(die.probabilities.expected).to be_within(1e-10).of 5.5

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(1, :<=, :reroll_use_best, 1)] )
      expect(die.probabilities.expected).to be_within(1e-10).of 7.15

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(1, :<=, :reroll_use_worst, 2)] )
      expect(die.probabilities.expected).to be_within(1e-10).of 3.025

      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(6, :<=, :reroll_add)] )
      expect(die.probabilities.expected).to be_within(1e-10).of 4.2

      die = GamesDice::ComplexDie.new(8, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_use_best)] )
      expect(die.probabilities.expected).to be_within(1e-10).of 5.0

      die = GamesDice::ComplexDie.new(4, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_replace, 1)] )
      expect(die.probabilities.expected).to be_within(1e-10).of 2.875
    end

    it "should calculate probabilities of each possible result" do
      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(7, :>, :reroll_add, 1)] )
      probs = die.probabilities.to_h
      expect(probs[11]).to be_within(1e-10).of 2/36.0
      expect(probs[8]).to be_within(1e-10).of 5/36.0
      expect(probs.values.inject(:+)).to be_within(1e-9).of 1.0

      die = GamesDice::ComplexDie.new(10, :rerolls => [GamesDice::RerollRule.new(10, :<=, :reroll_add)] )
      probs = die.probabilities.to_h
      expect(probs[8]).to be_within(1e-10).of 0.1
      expect(probs[10]).to be_nil
      expect(probs[13]).to be_within(1e-10).of 0.01
      expect(probs[27]).to be_within(1e-10).of 0.001
      expect(probs.values.inject(:+)).to be_within(1e-9).of 1.0

      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(1, :>=, :reroll_replace, 1)] )
      probs = die.probabilities.to_h
      expect(probs[1]).to be_within(1e-10).of 1/36.0
      expect(probs[2]).to be_within(1e-10).of 7/36.0
      expect(probs.values.inject(:+)).to be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      die = GamesDice::ComplexDie.new(6, :rerolls => [GamesDice::RerollRule.new(7, :>, :reroll_add, 1)] )
      probs = die.probabilities
      expect(probs.p_gt(7)).to be_within(1e-10).of 15/36.0
      expect(probs.p_gt(-10)).to eql 1.0
      expect(probs.p_gt(12)).to eql 0.0

      expect(probs.p_ge(7)).to be_within(1e-10).of 21/36.0
      expect(probs.p_ge(2)).to eql 1.0
      expect(probs.p_ge(15)).to eql 0.0

      expect(probs.p_lt(7)).to be_within(1e-10).of 15/36.0
      expect(probs.p_lt(-10)).to eql 0.0
      expect(probs.p_lt(13)).to eql 1.0

      expect(probs.p_le(7)).to be_within(1e-10).of 21/36.0
      expect(probs.p_le(1)).to eql 0.0
      expect(probs.p_le(12)).to eql 1.0
    end
  end

  describe "with maps" do
    it "should calculate correct minimum and maximum results" do
      die = GamesDice::ComplexDie.new( 10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S')] )
      expect(die.min).to eql 0
      expect(die.max).to eql 1
    end

    it "should simulate a d10 that scores 1 for success on a value of 7 or more" do
      die = GamesDice::ComplexDie.new( 10, :maps => [ [ 7, :<=, 1, 'S' ] ] )
      [0,0,1,0,1,1,0,1].each do |expected|
        expect(die.roll.value).to eql expected
        expect(die.result.value).to eql expected
      end
    end

    it "should label the mappings applied with the provided names" do
      die = GamesDice::ComplexDie.new( 10, :maps => [ [7, :<=, 1, 'S'], [1, :>=, -1, 'F'] ] )
      ["5", "4", "10 S", "4", "7 S", "8 S", "1 F", "9 S"].each do |expected|
        die.roll
        expect(die.explain_result).to eql expected
      end
    end

    it "should calculate an expected result" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      expect(die.probabilities.expected).to be_within(1e-10).of 0.3
    end

    it "should calculate probabilities of each possible result" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      probs_hash = die.probabilities.to_h
      expect(probs_hash[1]).to be_within(1e-10).of 0.4
      expect(probs_hash[0]).to be_within(1e-10).of 0.5
      expect(probs_hash[-1]).to be_within(1e-10).of 0.1
      expect(probs_hash.values.inject(:+)).to be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      die = GamesDice::ComplexDie.new(10, :maps => [GamesDice::MapRule.new(7, :<=, 1, 'S'),GamesDice::MapRule.new(1, :>=, -1, 'F')] )
      probs = die.probabilities
      expect(probs.p_gt(-2)).to eql 1.0
      expect(probs.p_gt(-1)).to be_within(1e-10).of 0.9
      expect(probs.p_gt(1)).to eql 0.0

      expect(probs.p_ge(1)).to be_within(1e-10).of 0.4
      expect(probs.p_ge(-1)).to eql 1.0
      expect(probs.p_ge(2)).to eql 0.0

      expect(probs.p_lt(1)).to be_within(1e-10).of 0.6
      expect(probs.p_lt(-1)).to eql 0.0
      expect(probs.p_lt(2)).to eql 1.0

      expect(probs.p_le(-1)).to be_within(1e-10).of 0.1
      expect(probs.p_le(-2)).to eql 0.0
      expect(probs.p_le(1)).to eql 1.0
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
      expect(@die.min).to eql 0
      expect(@die.max).to eql 1
    end

    it "should calculate an expected result" do
      expect(@die.probabilities.expected).to be_within(1e-10).of 4/36.0
    end

    it "should calculate probabilities of each possible result" do
      probs_hash = @die.probabilities.to_h
      expect(probs_hash[1]).to be_within(1e-10).of 4/36.0
      expect(probs_hash[0]).to be_within(1e-10).of 32/36.0
      expect(probs_hash.values.inject(:+)).to be_within(1e-9).of 1.0
    end

    it "should calculate aggregate probabilities" do
      probs = @die.probabilities

      expect(probs.p_gt(0)).to be_within(1e-10).of 4/36.0
      expect(probs.p_gt(-2)).to eql 1.0
      expect(probs.p_gt(1)).to eql 0.0

      expect(probs.p_ge(1)).to be_within(1e-10).of 4/36.0
      expect(probs.p_ge(-1)).to eql 1.0
      expect(probs.p_ge(2)).to eql 0.0

      expect(probs.p_lt(1)).to be_within(1e-10).of 32/36.0
      expect(probs.p_lt(0)).to eql 0.0
      expect(probs.p_lt(2)).to eql 1.0

      expect(probs.p_le(0)).to be_within(1e-10).of 32/36.0
      expect(probs.p_le(-1)).to eql 0.0
      expect(probs.p_le(1)).to eql 1.0
    end

    it "should apply mapping to final re-rolled result" do
      [0,1,0,0].each do |expected|
        expect(@die.roll.value).to eql expected
        expect(@die.result.value).to eql expected
      end
    end

    it "should explain how it got each result" do
      ["5", "[6+4] 10 Success", "[6+2] 8", "5"].each do |expected|
        @die.roll
        expect(@die.explain_result).to eql expected
      end
    end
  end # describe "with rerolls and maps"
end # describe GamesDice::ComplexDie
