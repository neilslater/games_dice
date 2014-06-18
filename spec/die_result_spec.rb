require 'helpers'

describe GamesDice::DieResult do

  describe ".new" do

    it "should work without parameters to represent 'no results yet'" do
      die_result = GamesDice::DieResult.new()
      die_result.value.should == nil
      die_result.rolls.should == []
      die_result.roll_reasons.should == []
    end

    it "should work with a single Integer param to represent an initial result" do
      die_result = GamesDice::DieResult.new(8)
      die_result.value.should == 8
      die_result.rolls.should == [8]
      die_result.roll_reasons.should == [:basic]
    end

    it "should not accept a param that cannot be coerced to Integer" do
      lambda { GamesDice::DieResult.new([]) }.should raise_error( TypeError )
      lambda { GamesDice::DieResult.new('N') }.should raise_error( ArgumentError )
    end

    it "should not accept unknown reasons for making a roll" do
      lambda { GamesDice::DieResult.new(8,'wooo') }.should raise_error( ArgumentError )
      lambda { GamesDice::DieResult.new(8,:frabulous) }.should raise_error( ArgumentError )
    end

  end

  describe "#add_roll" do

    context "starting from 'no results yet'" do
      let(:die_result) { GamesDice::DieResult.new() }

      it "should create an initial result" do
        die_result.add_roll(5)
        die_result.value.should == 5
        die_result.rolls.should == [5]
        die_result.roll_reasons.should == [:basic]
      end

      it "should accept non-basic reasons for the first roll" do
        die_result.add_roll(4,:reroll_subtract)
        die_result.value.should == -4
        die_result.rolls.should == [4]
        die_result.roll_reasons.should == [:reroll_subtract]
      end

      it "should not accept a first param that cannot be coerced to Integer" do
        lambda { die_result.add_roll([]) }.should raise_error( TypeError )
        lambda { die_result.add_roll('N') }.should raise_error( ArgumentError )
      end

      it "should not accept an unsupported second param" do
        lambda { die_result.add_roll(5,[]) }.should raise_error( ArgumentError )
        lambda { die_result.add_roll(15,:bam) }.should raise_error( ArgumentError )
      end

    end

    context "starting with an initial result" do
      let(:die_result) { GamesDice::DieResult.new(7) }

      it "should not accept a first param that cannot be coerced to Integer" do
        lambda { die_result.add_roll([]) }.should raise_error( TypeError )
        lambda { die_result.add_roll('N') }.should raise_error( ArgumentError )
      end

      it "should not accept an unsupported second param" do
        lambda { die_result.add_roll(5,[]) }.should raise_error( ArgumentError )
        lambda { die_result.add_roll(15,:bam) }.should raise_error( ArgumentError )
      end

      context "add another basic roll" do
        it "should replace an initial result, as if the die were re-rolled" do
          die_result.add_roll(5)
          die_result.value.should == 5
          die_result.rolls.should == [7,5]
          die_result.roll_reasons.should == [:basic, :basic]
        end
      end

      context "exploding dice" do
        it "should add to value when exploding up" do
          die_result.add_roll( 6, :reroll_add )
          die_result.value.should == 13
          die_result.rolls.should == [7,6]
          die_result.roll_reasons.should == [:basic, :reroll_add]
        end

        it "should subtract from value when exploding down" do
          die_result.add_roll( 4, :reroll_subtract )
          die_result.value.should == 3
          die_result.rolls.should == [7,4]
          die_result.roll_reasons.should == [:basic, :reroll_subtract]
        end
      end

      context "re-roll dice" do
        it "should optionally replace roll unconditionally" do
          die_result.add_roll( 2, :reroll_replace )
          die_result.value.should == 2
          die_result.rolls.should == [7,2]
          die_result.roll_reasons.should == [:basic, :reroll_replace]

          die_result.add_roll( 5, :reroll_replace )
          die_result.value.should == 5
          die_result.rolls.should == [7,2,5]
          die_result.roll_reasons.should == [:basic, :reroll_replace, :reroll_replace]
        end

        it "should optionally use best roll" do
          die_result.add_roll( 2, :reroll_use_best )
          die_result.value.should == 7
          die_result.rolls.should == [7,2]
          die_result.roll_reasons.should == [:basic, :reroll_use_best]

          die_result.add_roll( 9, :reroll_use_best )
          die_result.value.should == 9
          die_result.rolls.should == [7,2,9]
          die_result.roll_reasons.should == [:basic, :reroll_use_best, :reroll_use_best]
        end

        it "should optionally use worst roll" do
          die_result.add_roll( 4, :reroll_use_worst )
          die_result.value.should == 4
          die_result.rolls.should == [7,4]
          die_result.roll_reasons.should == [:basic, :reroll_use_worst]

          die_result.add_roll( 5, :reroll_use_worst )
          die_result.value.should == 4
          die_result.rolls.should == [7,4,5]
          die_result.roll_reasons.should == [:basic, :reroll_use_worst, :reroll_use_worst]
        end
      end

      context "combinations of reroll reasons" do
        it "should correctly handle valid reasons for extra rolls in combination" do
          die_result.add_roll( 10, :reroll_add )
          die_result.add_roll( 3, :reroll_subtract)
          die_result.value.should == 14
          die_result.rolls.should == [7,10,3]
          die_result.roll_reasons.should == [:basic, :reroll_add, :reroll_subtract]

          die_result.add_roll( 12, :reroll_replace )
          die_result.value.should == 12
          die_result.rolls.should == [7,10,3,12]
          die_result.roll_reasons.should == [:basic, :reroll_add, :reroll_subtract, :reroll_replace]

          die_result.add_roll( 9, :reroll_use_best )
          die_result.value.should == 12
          die_result.rolls.should == [7,10,3,12,9]
          die_result.roll_reasons.should == [:basic, :reroll_add, :reroll_subtract, :reroll_replace, :reroll_use_best]

          die_result.add_roll( 15, :reroll_add)
          die_result.value.should == 27
          die_result.rolls.should == [7,10,3,12,9,15]
          die_result.roll_reasons.should == [:basic, :reroll_add, :reroll_subtract, :reroll_replace, :reroll_use_best, :reroll_add]
        end
      end

    end

  end

  describe "#explain_value" do
    let(:die_result) { GamesDice::DieResult.new() }

    it "should be empty string for 'no results yet'" do
      die_result.explain_value.should == ''
    end

    it "should be a simple stringified number when there is one die roll" do
      die_result.add_roll(3)
      die_result.explain_value.should == '3'
    end

    it "should describe all single rolls made and how they combine" do
      die_result.add_roll(6)
      die_result.explain_value.should == '6'

      die_result.add_roll(5,:reroll_add)
      die_result.explain_value.should == '[6+5] 11'

      die_result.add_roll(2,:reroll_replace)
      die_result.explain_value.should == '[6+5|2] 2'

      die_result.add_roll(7,:reroll_subtract)
      die_result.explain_value.should == '[6+5|2-7] -5'

      die_result.add_roll(4,:reroll_use_worst)
      die_result.explain_value.should == '[6+5|2-7\\4] -5'

      die_result.add_roll(3,:reroll_use_best)
      die_result.explain_value.should == '[6+5|2-7\\4/3] 3'

    end

  end

  it "should combine via +,- and * intuitively based on #value" do
    die_result = GamesDice::DieResult.new(7)
    (die_result + 3).should == 10
    (4 + die_result).should == 11
    (die_result - 2).should == 5
    (9 - die_result).should == 2

    (die_result + 7.7).should == 14.7
    (4.1 + die_result).should == 11.1

    (die_result * 2).should == 14
    (1 * die_result).should == 7

    other_die_result = GamesDice::DieResult.new(6)
    other_die_result.add_roll(6,:reroll_add)
    (die_result + other_die_result).should == 19
    (other_die_result - die_result).should == 5
  end

  it "should support comparison with >,<,>=,<= as if it were an integer, based on #value" do
    die_result = GamesDice::DieResult.new(7)

    (die_result > 3).should == true
    (14 > die_result).should == true
    (die_result >= 7).should == true
    (9.5 >= die_result).should == true
    (die_result < 3).should == false
    (14 < die_result).should == false
    (die_result <= 8).should == true
    (14 <= die_result).should == false

    other_die_result = GamesDice::DieResult.new(6)
    other_die_result.add_roll(6,:reroll_add)
    (die_result > other_die_result).should == false
    (other_die_result > die_result).should == true
    (die_result >= other_die_result).should == false
    (other_die_result >= die_result).should == true
    (die_result < other_die_result).should == true
    (other_die_result < die_result).should == false
    (die_result <= other_die_result).should == true
    (other_die_result <= die_result).should == false

  end

  it "should sort, based on #value" do
    die_results = [
      GamesDice::DieResult.new(7), GamesDice::DieResult.new(5), GamesDice::DieResult.new(8), GamesDice::DieResult.new(3)
    ]

    die_results.sort!

    die_results[0].value.should == 3
    die_results[1].value.should == 5
    die_results[2].value.should == 7
    die_results[3].value.should == 8
  end

end
