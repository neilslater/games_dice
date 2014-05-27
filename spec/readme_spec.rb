require 'helpers'
# This spec demonstrates that documentation from the README.md works as intended

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

      (0..5).each do |dresult|
        prng.stub( :rand ) { dresult }
        expect( prng ).to receive(:rand).with(6)
        d.roll.should == (dresult + 1) * 3
      end
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

  describe "#explain_result" do
    it "attempts to show how the result from the last call to roll was composed" do
      expected_results = [
        "3d6: 3 + 6 + 2 = 11",
        "3d6: 4 + 5 + 6 = 15",
        "3d6: 3 + 6 + 2 = 11",
        "3d6: 5 + 6 + 1 = 12"
        ]
      expected_results.each do |expected|
        dice.roll
        dice.explain_result.should == expected
      end
    end

    it "will be nil if no roll has been made yet" do
      dice.explain_result.should be_nil
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

describe GamesDice::Probabilities do
  let(:probs) { GamesDice.create('3d6').probabilities }

  describe "#to_h" do
    it "returns a hash representation of the probability distribution" do
      h = probs.to_h
      h.should be_valid_distribution
      h[3].should be_within(1e-10).of 1.0/216
      h[11].should be_within(1e-10).of 27.0/216
    end
  end

  describe "#max" do
    it "returns maximum result in the probability distribution" do
      probs.max.should == 18
    end
  end

  describe "#min" do
    it "returns minimum result in the probability distribution" do
      probs.min.should == 3
    end
  end

  describe "#p_eql( n )" do
    it "returns the probability of a result equal to the integer n" do
      probs.p_eql( 3 ).should be_within(1e-10).of 1.0/216
      probs.p_eql( 2 ).should == 0.0
    end
  end

  describe "#p_gt( n )" do
    it "returns the probability of a result greater than the integer n" do
      probs.p_gt( 17 ).should be_within(1e-10).of 1.0/216
      probs.p_gt( 2 ).should == 1.0
    end
  end

  describe "#p_ge( n )" do
    it "returns the probability of a result greater than the integer n" do
      probs.p_ge( 17 ).should be_within(1e-10).of 4.0/216
      probs.p_ge( 3 ).should == 1.0
    end
  end

  describe "#p_le( n )" do
    it "returns the probability of a result less than or equal to the integer n" do
      probs.p_le( 17 ).should be_within(1e-10).of 215.0/216
      probs.p_le( 3 ).should be_within(1e-10).of 1.0/216
    end
  end

  describe "#p_lt( n )" do
    it "returns the probability of a result less than the integer n" do
      probs.p_lt( 17 ).should be_within(1e-10).of 212.0/216
      probs.p_lt( 3 ).should == 0.0
    end
  end

end  # describe GamesDice::Probabilities

describe 'String Dice Description' do

  before :each do
    srand(35241)
  end

  describe "'1d6'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '1d6'
      (1..20).map { |n| d.roll }.should == [6, 3, 2, 3, 4, 6, 4, 2, 6, 3, 3, 5, 6, 6, 3, 6, 5, 2, 1, 4]
    end
  end

  describe "'2d6 + 1d4'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '2d6 + 1d4'
      (1..5).map { |n| d.roll }.should == [11, 10, 12, 12, 14]
    end
  end

  describe "'1d100 + 1d20 - 5'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '1d100 + 1d20 - 5'
      (1..5).map { |n| d.roll }.should == [75, 78, 24, 102, 32]
    end
  end

  describe "'1d10x'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '1d10x'
      (1..20).map { |n| d.roll }.should == [2, 3, 4, 7, 6, 7, 4, 2, 6, 3, 7, 5, 6, 7, 6, 6, 5, 19, 4, 19]
    end
  end

  describe "'1d6r1'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '1d6r1'
      (1..20).map { |n| d.roll }.should == [6, 3, 2, 3, 4, 6, 4, 2, 6, 3, 3, 5, 6, 6, 3, 6, 5, 2, 4, 2]
    end
  end

  describe "'5d10r:10,add.k2'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '5d10r:10,add.k2'
      (1..5).map { |n| d.roll }.should == [13, 13, 14, 38, 15]
    end
  end

  describe "'3d10m6'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '3d10m6'
      (1..6).map { |n| d.roll }.should == [0, 3, 1, 1, 3, 2]
    end
  end

  describe "'5d10k2'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '5d10k2'
      (1..5).map { |n| d.roll }.should == [13, 13, 14, 19, 19]
    end
  end

  describe "'5d10x'" do
    it "is the same as '5d10r:10,add.'" do
      srand(235241)
      d = GamesDice.create '5d10x'
      results1 = (1..50).map { d.roll }

      srand(235241)
      d = GamesDice.create '5d10r:10,add.'
      results2 = (1..50).map { d.roll }

      results1.should == results2
    end
  end

  describe "'1d6r:1.'" do
    it "should return same as '1d6r1'" do
      srand(235241)
      d = GamesDice.create '1d6r:1.'
      results1 = (1..50).map { d.roll }

      srand(235241)
      d = GamesDice.create '1d6r1'
      results2 = (1..50).map { d.roll }

      results1.should == results2
    end
  end

  describe "'1d10r:10,replace,1.'" do
    it "should roll a 10-sided die, re-roll a result of 10 and take the value of the second roll" do
      d = GamesDice.create '1d10r:10,replace,1.'
      (1..27).map { d.roll }.should == [2, 3, 4, 7, 6, 7, 4, 2, 6, 3, 7, 5, 6, 7, 6, 6, 5, 9, 4, 9, 8, 3, 1, 6, 7, 1, 1]
    end
  end

  describe "'1d20r:<=10,use_best,1.'" do
    it "should roll a 20-sided die, re-roll a result if 10 or lower, and use best result" do
      d = GamesDice.create '1d20r:<=10,use_best,1.'
      (1..20).map { d.roll }.should == [ 18, 19, 20, 20, 3, 11, 7, 20, 15, 19, 6, 16, 17, 16, 15, 11, 9, 15, 20, 16 ]
    end
  end

  describe "'5d10r:10,add.k2', '5d10xk2' and '5d10x.k2'" do
    it "should all be equivalent" do
      srand(135241)
      d = GamesDice.create '5d10r:10,add.k2'
      results1 = (1..50).map { d.roll }

      srand(135241)
      d = GamesDice.create '5d10xk2'
      results2 = (1..50).map { d.roll }

      srand(135241)
      d = GamesDice.create '5d10x.k2'
      results3 = (1..50).map { d.roll }

      results1.should == results2
      results2.should == results3
    end
  end

  describe "'5d10r:>8,add.'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '5d10r:>8,add.'
      (1..5).map { |n| d.roll }.should == [22, 22, 31, 64, 26]
    end
  end

  describe "'9d6x.m:10.'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '9d6x.m:10.'
      (1..5).map { |n| d.roll }.should == [1, 2, 1, 1, 1]
    end
    it "can be explained as number of exploding dice scoring 10+" do
      d = GamesDice.create '9d6x.m:10.'
      (1..5).map { |n| d.roll; d.explain_result }.should == [
            "9d6: [6+3] 9, 2, 3, 4, [6+4] 10, 2, [6+3] 9, 3, 5. Successes: 1",
            "9d6: [6+6+3] 15, [6+5] 11, 2, 1, 4, 2, 1, 3, 5. Successes: 2",
            "9d6: 1, [6+6+1] 13, 2, 1, 1, 3, [6+1] 7, 5, 4. Successes: 1",
            "9d6: [6+4] 10, 3, 4, 5, 5, 1, [6+3] 9, 3, 5. Successes: 1",
            "9d6: [6+3] 9, 3, [6+5] 11, 4, 2, 2, 1, 4, 5. Successes: 1"
      ]
    end
  end

  describe "'9d6x.m:10,1,S.'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '9d6x.m:10,1,S.'
      (1..5).map { |n| d.roll }.should == [1, 2, 1, 1, 1]
    end
    it "includes the string 'S' next to each success" do
      d = GamesDice.create '9d6x.m:10,1,S.'
      (1..5).map { |n| d.roll; d.explain_result }.should == [
            "9d6: [6+3] 9, 2, 3, 4, [6+4] 10 S, 2, [6+3] 9, 3, 5. Successes: 1",
            "9d6: [6+6+3] 15 S, [6+5] 11 S, 2, 1, 4, 2, 1, 3, 5. Successes: 2",
            "9d6: 1, [6+6+1] 13 S, 2, 1, 1, 3, [6+1] 7, 5, 4. Successes: 1",
            "9d6: [6+4] 10 S, 3, 4, 5, 5, 1, [6+3] 9, 3, 5. Successes: 1",
            "9d6: [6+3] 9, 3, [6+5] 11 S, 4, 2, 2, 1, 4, 5. Successes: 1"
      ]
    end
  end

  describe "'5d10m:>=6,1,S.m:==1,-1,F.'" do
    it "returns expected results from rolling" do
      d = GamesDice.create '5d10m:>=6,1,S.m:==1,-1,F.'
      (1..10).map { |n| d.roll }.should == [2, 2, 4, 3, 2, 1, 1, 3, 3, 0]
    end
    it "includes the string 'S' next to each success, and 'F' next to each 'fumble'" do
      d = GamesDice.create '5d10m:>=6,1,S.m:==1,-1,F.'
      (1..5).map { |n| d.roll; d.explain_result }.should ==  [
            "5d10: 2, 3, 4, 7 S, 6 S. Successes: 2",
            "5d10: 7 S, 4, 2, 6 S, 3. Successes: 2",
            "5d10: 7 S, 5, 6 S, 7 S, 6 S. Successes: 4",
            "5d10: 6 S, 5, 10 S, 9 S, 4. Successes: 3",
            "5d10: 10 S, 9 S, 8 S, 3, 1 F. Successes: 2"
        ]
    end
  end

  describe "'4d6k:3.r:1,replace,1.'" do
    it "represents roll 4 six-sided dice, re-roll any 1s, and keep best 3." do
      d = GamesDice.create '4d6k:3.r:1,replace,1.'
      (1..10).map { |n| d.roll }.should == [12, 14, 14, 18, 11, 17, 11, 15, 14, 14]
    end
    it "includes re-rolls and keeper choice in explanations" do
      d = GamesDice.create '4d6k:3.r:1,replace,1.'
      (1..5).map { |n| d.roll; d.explain_result }.should ==  [
          "4d6: 6, 3, 2, 3. Keep: 3 + 3 + 6 = 12",
          "4d6: 4, 6, 4, 2. Keep: 4 + 4 + 6 = 14",
          "4d6: 6, 3, 3, 5. Keep: 3 + 5 + 6 = 14",
          "4d6: 6, 6, 3, 6. Keep: 6 + 6 + 6 = 18",
          "4d6: 5, 2, [1|4] 4, 2. Keep: 2 + 4 + 5 = 11"
      ]
    end
  end

  describe "'2d20k:1,worst.'" do
    it "represents roll 2 twenty-sided dice, return lowest of the two results" do
      d = GamesDice.create '2d20k:1,worst.'
      (1..10).map { |n| d.roll }.should == [18, 6, 2, 3, 5, 10, 15, 1, 7, 10]
    end
    it "includes keeper choice in explanations" do
      d = GamesDice.create '2d20k:1,worst.'
      (1..5).map { |n| d.roll; d.explain_result }.should ==  [
          "2d20: 18, 19. Keep: 18",
          "2d20: 20, 6. Keep: 6",
          "2d20: 20, 2. Keep: 2",
          "2d20: 3, 11. Keep: 3",
          "2d20: 5, 7. Keep: 5"
      ]
    end
  end

end
