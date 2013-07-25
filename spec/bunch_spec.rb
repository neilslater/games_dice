require 'helpers'

describe GamesDice::Bunch do

  describe "dice scheme" do

    before :each do
      srand(67809)
    end

    describe '1d10' do
      let(:bunch) { GamesDice::Bunch.new( :sides => 10, :ndice => 1 ) }

      it "should simulate rolling a ten-sided die" do
        [3,2,8,8,5,3,7].each do |expected_total|
          bunch.roll.should == expected_total
          bunch.result.should == expected_total
        end
      end

      it "should concisely explain each result" do
        ["3", "2", "8", "8"].each do |expected_explain|
          bunch.roll
          bunch.explain_result.should == expected_explain
        end
      end

      it "should calculate correct min, max = 1,10" do
        bunch.min.should == 1
        bunch.max.should == 10
      end

      it "should have a mean value of 5.5" do
        bunch.probabilities.expected.should be_within(1e-10).of 5.5
      end

      it "should calculate probabilities correctly" do
        prob_hash = bunch.probabilities.to_h
        prob_hash[1].should be_within(1e-10).of 0.1
        prob_hash[2].should be_within(1e-10).of 0.1
        prob_hash[3].should be_within(1e-10).of 0.1
        prob_hash[4].should be_within(1e-10).of 0.1
        prob_hash[5].should be_within(1e-10).of 0.1
        prob_hash[6].should be_within(1e-10).of 0.1
        prob_hash[7].should be_within(1e-10).of 0.1
        prob_hash[8].should be_within(1e-10).of 0.1
        prob_hash[9].should be_within(1e-10).of 0.1
        prob_hash[10].should be_within(1e-10).of 0.1
        prob_hash.values.inject(:+).should be_within(1e-9).of 1.0
      end
    end

    describe '2d6' do
      let(:bunch) { GamesDice::Bunch.new( :sides => 6, :ndice => 2 ) }

      it "should simulate rolling two six-sided dice and adding them" do
        [9,6,11,9,7,7,10].each do |expected_total|
          bunch.roll.should == expected_total
          bunch.result.should == expected_total
        end
      end

      it "should concisely explain each result" do
        ["3 + 6 = 9","2 + 4 = 6","5 + 6 = 11","3 + 6 = 9","2 + 5 = 7","6 + 1 = 7","5 + 5 = 10",].each do |expected_explain|
          bunch.roll
          bunch.explain_result.should == expected_explain
        end
      end

      it "should calculate correct min, max = 2,12" do
        bunch.min.should == 2
        bunch.max.should == 12
      end

      it "should have a mean value of 7.0" do
        bunch.probabilities.expected.should be_within(1e-10).of 7.0
      end

      it "should calculate probabilities correctly" do
        prob_hash = bunch.probabilities.to_h
        prob_hash[2].should be_within(1e-10).of 1/36.0
        prob_hash[3].should be_within(1e-10).of 2/36.0
        prob_hash[4].should be_within(1e-10).of 3/36.0
        prob_hash[5].should be_within(1e-10).of 4/36.0
        prob_hash[6].should be_within(1e-10).of 5/36.0
        prob_hash[7].should be_within(1e-10).of 6/36.0
        prob_hash[8].should be_within(1e-10).of 5/36.0
        prob_hash[9].should be_within(1e-10).of 4/36.0
        prob_hash[10].should be_within(1e-10).of 3/36.0
        prob_hash[11].should be_within(1e-10).of 2/36.0
        prob_hash[12].should be_within(1e-10).of 1/36.0
        prob_hash.values.inject(:+).should be_within(1e-9).of 1.0
      end
    end

    describe '20d10' do
      let(:bunch) { GamesDice::Bunch.new( :sides => 10, :ndice => 20 ) }

      it "should simulate rolling twenty ten-sided dice and adding them" do
        [132,103,102,124,132,96,111].each do |expected_total|
          bunch.roll.should == expected_total
          bunch.result.should == expected_total
        end
      end

      it "should concisely explain each result" do
        ["3 + 2 + 8 + 8 + 5 + 3 + 7 + 7 + 6 + 10 + 7 + 6 + 9 + 5 + 5 + 8 + 10 + 9 + 5 + 9 = 132",
         "3 + 9 + 1 + 4 + 3 + 5 + 7 + 1 + 10 + 4 + 7 + 7 + 6 + 5 + 2 + 7 + 4 + 9 + 7 + 2 = 103",
         "6 + 1 + 1 + 3 + 1 + 4 + 9 + 6 + 3 + 10 + 9 + 10 + 8 + 4 + 1 + 4 + 2 + 1 + 10 + 9 = 102",
         ].each do |expected_explain|
          bunch.roll
          bunch.explain_result.should == expected_explain
        end
      end

      it "should calculate correct min, max = 20,200" do
        bunch.min.should == 20
        bunch.max.should == 200
      end

      it "should have a mean value of 110.0" do
        bunch.probabilities.expected.should be_within(1e-8).of 110.0
      end

      it "should calculate probabilities correctly" do
        prob_hash = bunch.probabilities.to_h
        prob_hash[20].should be_within(1e-26).of 1e-20
        prob_hash[110].should be_within(1e-10).of 0.0308191892
        prob_hash.values.inject(:+).should be_within(1e-9).of 1.0
      end
    end

    describe '4d6 keep best 3' do
      let(:bunch) { GamesDice::Bunch.new( :sides => 6, :ndice => 4, :keep_mode => :keep_best, :keep_number => 3 ) }

      it "should simulate rolling four six-sided dice and adding the best three values" do
        [13,17,13,12,13,10,14].each do |expected_total|
          bunch.roll.should == expected_total
          bunch.result.should == expected_total
        end
      end

      it "should concisely explain each result" do
        ["3, 6, 2, 4. Keep: 3 + 4 + 6 = 13",
         "5, 6, 3, 6. Keep: 5 + 6 + 6 = 17",
         "2, 5, 6, 1. Keep: 2 + 5 + 6 = 13",
         "5, 5, 2, 1. Keep: 2 + 5 + 5 = 12",
         ].each do |expected_explain|
          bunch.roll
          bunch.explain_result.should == expected_explain
        end
      end

      it "should calculate correct min, max = 3,18" do
        bunch.min.should == 3
        bunch.max.should == 18
      end

      it "should have a mean value of roughly 12.2446" do
        bunch.probabilities.expected.should be_within(1e-9).of 12.244598765
      end

      it "should calculate probabilities correctly" do
        prob_hash = bunch.probabilities.to_h
        prob_hash[3].should be_within(1e-10).of 1/1296.0
        prob_hash[4].should be_within(1e-10).of 4/1296.0
        prob_hash[5].should be_within(1e-10).of 10/1296.0
        prob_hash[6].should be_within(1e-10).of 21/1296.0
        prob_hash[7].should be_within(1e-10).of 38/1296.0
        prob_hash[8].should be_within(1e-10).of 62/1296.0
        prob_hash[9].should be_within(1e-10).of 91/1296.0
        prob_hash[10].should be_within(1e-10).of 122/1296.0
        prob_hash[11].should be_within(1e-10).of 148/1296.0
        prob_hash[12].should be_within(1e-10).of 167/1296.0
        prob_hash[13].should be_within(1e-10).of 172/1296.0
        prob_hash[14].should be_within(1e-10).of 160/1296.0
        prob_hash[15].should be_within(1e-10).of 131/1296.0
        prob_hash[16].should be_within(1e-10).of 94/1296.0
        prob_hash[17].should be_within(1e-10).of 54/1296.0
        prob_hash[18].should be_within(1e-10).of 21/1296.0
        prob_hash.values.inject(:+).should be_within(1e-9).of 1.0
      end
    end

    describe '10d10 keep worst one' do
      let(:bunch) { GamesDice::Bunch.new( :sides => 10, :ndice => 10, :keep_mode => :keep_worst, :keep_number => 1 ) }

      it "should simulate rolling ten ten-sided dice and keeping the worst value" do
        [2,5,1,2,1,1,2].each do |expected_total|
          bunch.roll.should == expected_total
          bunch.result.should == expected_total
        end
      end

      it "should concisely explain each result" do
        ["3, 2, 8, 8, 5, 3, 7, 7, 6, 10. Keep: 2",
         "7, 6, 9, 5, 5, 8, 10, 9, 5, 9. Keep: 5",
         "3, 9, 1, 4, 3, 5, 7, 1, 10, 4. Keep: 1",
         "7, 7, 6, 5, 2, 7, 4, 9, 7, 2. Keep: 2",
         ].each do |expected_explain|
          bunch.roll
          bunch.explain_result.should == expected_explain
        end
      end

      it "should calculate correct min, max = 1,10" do
        bunch.min.should == 1
        bunch.max.should == 10
      end

      it "should have a mean value of roughly 1.491" do
        bunch.probabilities.expected.should be_within(1e-9).of 1.4914341925
      end

      it "should calculate probabilities correctly" do
        prob_hash = bunch.probabilities.to_h
        prob_hash[1].should be_within(1e-10).of 0.6513215599
        prob_hash[2].should be_within(1e-10).of 0.2413042577
        prob_hash[3].should be_within(1e-10).of 0.0791266575
        prob_hash[4].should be_within(1e-10).of 0.0222009073
        prob_hash[5].should be_within(1e-10).of 0.0050700551
        prob_hash[6].should be_within(1e-10).of 0.0008717049
        prob_hash[7].should be_within(1e-10).of 0.0000989527
        prob_hash[8].should be_within(1e-10).of 0.0000058025
        prob_hash[9].should be_within(1e-10).of 0.0000001023
        prob_hash[10].should be_within(1e-18).of 1e-10
        prob_hash.values.inject(:+).should be_within(1e-9).of 1.0
      end
    end

    describe '5d10, re-roll and add on 10s, keep best 2' do
      let(:bunch) {
        GamesDice::Bunch.new(
          :sides => 10, :ndice => 5, :keep_mode => :keep_best, :keep_number => 2,
          :rerolls => [GamesDice::RerollRule.new(10,:==,:reroll_add)]
          ) }

      it "should simulate rolling five ten-sided 'exploding' dice and adding the best two values" do
        [16,24,17,28,12,21,16].each do |expected_total|
          bunch.roll.should == expected_total
          bunch.result.should == expected_total
        end
      end

      it "should concisely explain each result" do
        ["3, 2, 8, 8, 5. Keep: 8 + 8 = 16",
         "3, 7, 7, 6, [10+7] 17. Keep: 7 + 17 = 24",
         "6, 9, 5, 5, 8. Keep: 8 + 9 = 17",
         "[10+9] 19, 5, 9, 3, 9. Keep: 9 + 19 = 28",
         ].each do |expected_explain|
          bunch.roll
          bunch.explain_result.should == expected_explain
        end
      end

      it "should calculate correct min, max = 2, > 100" do
        bunch.min.should == 2
        bunch.max.should > 100
      end

      it "should have a mean value of roughly 18.986" do
        bunch.probabilities.expected.should be_within(1e-9).of 18.9859925804
      end

      it "should calculate probabilities correctly" do
        prob_hash = bunch.probabilities.to_h
        prob_hash[2].should be_within(1e-10).of 0.00001
        prob_hash[3].should be_within(1e-10).of 0.00005
        prob_hash[4].should be_within(1e-10).of 0.00031
        prob_hash[5].should be_within(1e-10).of 0.00080
        prob_hash[6].should be_within(1e-10).of 0.00211
        prob_hash[7].should be_within(1e-10).of 0.00405
        prob_hash[8].should be_within(1e-10).of 0.00781
        prob_hash[9].should be_within(1e-10).of 0.01280
        prob_hash[10].should be_within(1e-10).of 0.02101
        prob_hash[12].should be_within(1e-10).of 0.045715
        prob_hash[13].should be_within(1e-10).of 0.060830
        prob_hash[14].should be_within(1e-10).of 0.077915
        prob_hash[15].should be_within(1e-10).of 0.090080
        prob_hash[16].should be_within(1e-10).of 0.097935
        prob_hash[17].should be_within(1e-10).of 0.091230
        prob_hash[18].should be_within(1e-10).of 0.070015
        prob_hash[19].should be_within(1e-10).of 0.020480
        prob_hash[20].should be_within(1e-10).of 0.032805
        prob_hash[22].should be_within(1e-10).of 0.0334626451
        prob_hash[23].should be_within(1e-10).of 0.0338904805
        prob_hash[24].should be_within(1e-10).of 0.0338098781
        prob_hash[25].should be_within(1e-10).of 0.0328226480
        prob_hash[26].should be_within(1e-10).of 0.0304393461
        prob_hash[27].should be_within(1e-10).of 0.0260456005
        prob_hash[28].should be_within(1e-10).of 0.0189361531
        prob_hash[29].should be_within(1e-10).of 0.0082804480
        prob_hash[30].should be_within(1e-10).of 0.0103524151
        prob_hash.values.inject(:+).should be_within(1e-9).of 1.0
      end
    end

    describe 'roll 2d20, keep best value' do
      let(:bunch) do
        GamesDice::Bunch.new(
          :sides => 20, :ndice => 2, :keep_mode => :keep_best, :keep_number => 1
        )
      end

      it "should simulate rolling two twenty-sided dice and keeping the best value" do
        [19,18,14,6,13,10,16].each do |expected_total|
          bunch.roll.should == expected_total
          bunch.result.should == expected_total
        end
      end

      it "should concisely explain each result" do
        ["19, 14. Keep: 19",
         "18, 16. Keep: 18",
         "5, 14. Keep: 14",
         "3, 6. Keep: 6",
         ].each do |expected_explain|
          bunch.roll
          bunch.explain_result.should == expected_explain
        end
      end

      it "should calculate correct min, max = 1,20" do
        bunch.min.should == 1
        bunch.max.should == 20
      end

      it "should have a mean value of 13.825" do
        bunch.probabilities.expected.should be_within(1e-9).of 13.825
      end

      it "should calculate probabilities correctly" do
        prob_hash = bunch.probabilities.to_h
        prob_hash[1].should be_within(1e-10).of 1/400.0
        prob_hash[2].should be_within(1e-10).of 3/400.0
        prob_hash[3].should be_within(1e-10).of 5/400.0
        prob_hash[4].should be_within(1e-10).of 7/400.0
        prob_hash[5].should be_within(1e-10).of 9/400.0
        prob_hash[6].should be_within(1e-10).of 11/400.0
        prob_hash[7].should be_within(1e-10).of 13/400.0
        prob_hash[8].should be_within(1e-10).of 15/400.0
        prob_hash[9].should be_within(1e-10).of 17/400.0
        prob_hash[10].should be_within(1e-10).of 19/400.0
        prob_hash[11].should be_within(1e-10).of 21/400.0
        prob_hash[12].should be_within(1e-10).of 23/400.0
        prob_hash[13].should be_within(1e-10).of 25/400.0
        prob_hash[14].should be_within(1e-10).of 27/400.0
        prob_hash[15].should be_within(1e-10).of 29/400.0
        prob_hash[16].should be_within(1e-10).of 31/400.0
        prob_hash[17].should be_within(1e-10).of 33/400.0
        prob_hash[18].should be_within(1e-10).of 35/400.0
        prob_hash[19].should be_within(1e-10).of 37/400.0
        prob_hash[20].should be_within(1e-10).of 39/400.0
        prob_hash.values.inject(:+).should be_within(1e-9).of 1.0
      end
    end

    describe 'roll 2d20, keep worst value' do
      let(:bunch) do
        GamesDice::Bunch.new(
          :sides => 20, :ndice => 2, :keep_mode => :keep_worst, :keep_number => 1
        )
      end

      it "should simulate rolling two twenty-sided dice and keeping the best value" do
        [14,16,5,3,7,5,9].each do |expected_total|
          bunch.roll.should == expected_total
          bunch.result.should == expected_total
        end
      end

      it "should concisely explain each result" do
        ["19, 14. Keep: 14",
         "18, 16. Keep: 16",
         "5, 14. Keep: 5",
         "3, 6. Keep: 3",
         ].each do |expected_explain|
          bunch.roll
          bunch.explain_result.should == expected_explain
        end
      end

      it "should calculate correct min, max = 1,20" do
        bunch.min.should == 1
        bunch.max.should == 20
      end

      it "should have a mean value of 7.175" do
        bunch.probabilities.expected.should be_within(1e-9).of 7.175
      end

      it "should calculate probabilities correctly" do
        prob_hash = bunch.probabilities.to_h
        prob_hash[1].should be_within(1e-10).of 39/400.0
        prob_hash[2].should be_within(1e-10).of 37/400.0
        prob_hash[3].should be_within(1e-10).of 35/400.0
        prob_hash[4].should be_within(1e-10).of 33/400.0
        prob_hash[5].should be_within(1e-10).of 31/400.0
        prob_hash[6].should be_within(1e-10).of 29/400.0
        prob_hash[7].should be_within(1e-10).of 27/400.0
        prob_hash[8].should be_within(1e-10).of 25/400.0
        prob_hash[9].should be_within(1e-10).of 23/400.0
        prob_hash[10].should be_within(1e-10).of 21/400.0
        prob_hash[11].should be_within(1e-10).of 19/400.0
        prob_hash[12].should be_within(1e-10).of 17/400.0
        prob_hash[13].should be_within(1e-10).of 15/400.0
        prob_hash[14].should be_within(1e-10).of 13/400.0
        prob_hash[15].should be_within(1e-10).of 11/400.0
        prob_hash[16].should be_within(1e-10).of 9/400.0
        prob_hash[17].should be_within(1e-10).of 7/400.0
        prob_hash[18].should be_within(1e-10).of 5/400.0
        prob_hash[19].should be_within(1e-10).of 3/400.0
        prob_hash[20].should be_within(1e-10).of 1/400.0
        prob_hash.values.inject(:+).should be_within(1e-9).of 1.0
      end
    end

  end

end
