require 'helpers'

describe GamesDice::Dice do

  describe "dice scheme" do

    before :each do
      srand(67809)
    end

    describe '1d10+2' do
      let(:dice) { GamesDice::Dice.new( [ { :sides => 10, :ndice => 1 } ], 2 ) }

      it "should simulate rolling a ten-sided die, and adding two to each result" do
        [5,4,10,10,7,5,9].each do |expected_total|
          dice.roll.should == expected_total
          dice.result.should == expected_total
        end
      end
    end

    describe '2d6+6' do
      let(:dice) { GamesDice::Dice.new( [ { :sides => 6, :ndice => 2 } ], 6) }

      it "should simulate rolling two six-sided dice and adding six to the result" do
        [15,12,17,15,13,13,16].each do |expected_total|
          dice.roll.should == expected_total
          dice.result.should == expected_total
        end
      end
    end

  end
end
