require 'games_dice'
require 'helpers'

describe GamesDice::Probabilities do
  describe "class methods" do
    describe "#new" do
      it "should create a new distribution from an array and offset" do
        pr = GamesDice::Probabilities.new( [1.0], 1 )
        pr.should be_a GamesDice::Probabilities
        pr.to_h.should be_valid_distribution
      end
    end

    describe "#for_fair_die" do
      it "should create a new distribution based on number of sides" do
        pr2 = GamesDice::Probabilities.for_fair_die( 2 )
        pr2.should be_a GamesDice::Probabilities
        pr2.to_h.should == { 1 => 0.5, 2 => 0.5 }
        (1..20).each do |sides|
          pr = GamesDice::Probabilities.for_fair_die( sides )
          pr.should be_a GamesDice::Probabilities
          h = pr.to_h
          h.should be_valid_distribution
          h.keys.count.should == sides
          h.values.each { |v| v.should be_within(1e-10).of 1.0/sides }
        end
      end
    end

    describe "#add_distributions" do
      it "should combine two distributions to create a third one" do
        d4a = GamesDice::Probabilities.new( [ 1.0/4, 1.0/4, 1.0/4, 1.0/4 ], 1 )
        d4b = GamesDice::Probabilities.new( [ 1.0/10, 2.0/10, 3.0/10, 4.0/10], 1 )
        pr = GamesDice::Probabilities.add_distributions( d4a, d4b )
        pr.to_h.should be_valid_distribution
      end

      it "should calculate a classic 2d6 distribution accurately" do
        d6 = GamesDice::Probabilities.for_fair_die( 6 )
        pr = GamesDice::Probabilities.add_distributions( d6, d6 )
        h = pr.to_h
        h.should be_valid_distribution
        h[2].should be_within(1e-9).of 1.0/36
        h[3].should be_within(1e-9).of 2.0/36
        h[4].should be_within(1e-9).of 3.0/36
        h[5].should be_within(1e-9).of 4.0/36
        h[6].should be_within(1e-9).of 5.0/36
        h[7].should be_within(1e-9).of 6.0/36
        h[8].should be_within(1e-9).of 5.0/36
        h[9].should be_within(1e-9).of 4.0/36
        h[10].should be_within(1e-9).of 3.0/36
        h[11].should be_within(1e-9).of 2.0/36
        h[12].should be_within(1e-9).of 1.0/36
      end
    end

    describe "#add_distributions_mult" do
      it "should combine two multiplied distributions to create a third one" do
        d4a = GamesDice::Probabilities.new( [ 1.0/4, 1.0/4, 1.0/4, 1.0/4 ], 1 )
        d4b = GamesDice::Probabilities.new( [ 1.0/10, 2.0/10, 3.0/10, 4.0/10], 1 )
        pr = GamesDice::Probabilities.add_distributions_mult( 2, d4a, -1, d4b )
        pr.to_h.should be_valid_distribution
      end

      it "should calculate a distribution for '1d6 - 1d4' accurately" do
        d6 = GamesDice::Probabilities.for_fair_die( 6 )
        d4 = GamesDice::Probabilities.for_fair_die( 4 )
        pr = GamesDice::Probabilities.add_distributions_mult( 1, d6, -1, d4 )
        h = pr.to_h
        h.should be_valid_distribution
        h[-3].should be_within(1e-9).of 1.0/24
        h[-2].should be_within(1e-9).of 2.0/24
        h[-1].should be_within(1e-9).of 3.0/24
        h[0].should be_within(1e-9).of 4.0/24
        h[1].should be_within(1e-9).of 4.0/24
        h[2].should be_within(1e-9).of 4.0/24
        h[3].should be_within(1e-9).of 3.0/24
        h[4].should be_within(1e-9).of 2.0/24
        h[5].should be_within(1e-9).of 1.0/24
      end

      it "should add asymmetric distributions accurately" do
        da = GamesDice::Probabilities.new( [0.7,0.0,0.3], 2 )
        db = GamesDice::Probabilities.new( [0.5,0.3,0.2], 2 )
        pr = GamesDice::Probabilities.add_distributions_mult( 1, da, 2, db )
        h = pr.to_h
        h.should be_valid_distribution
        h[6].should be_within(1e-9).of 0.7 * 0.5
        h[8].should be_within(1e-9).of 0.7 * 0.3 + 0.3 * 0.5
        h[10].should be_within(1e-9).of 0.7 * 0.2 + 0.3 * 0.3
        h[12].should be_within(1e-9).of 0.3 * 0.2
      end
    end

    describe "#from_h" do
      it "should create a Probabilities object from a valid hash" do
        pr = GamesDice::Probabilities.from_h( { 7 => 0.5, 9 => 0.5 } )
        pr.should be_a GamesDice::Probabilities
      end

      it "should raise an ArgumentError when called with a non-valid hash" do
        # lambda { GamesDice::Probabilities.from_h( :foo ) }.should raise_error ArgumentError
        lambda { GamesDice::Probabilities.from_h( { 7 => 0.5, 9 => 0.6 } ) }.should raise_error ArgumentError
      end
    end

    describe "#implemented_in" do
      it "should be either :c or :ruby" do
        lang = GamesDice::Probabilities.implemented_in
        lang.should be_a Symbol
        [:c, :ruby].member?( lang ).should be_true
      end
    end
  end # describe "class methods"

  describe "instance methods" do
    let(:pr2) { GamesDice::Probabilities.for_fair_die( 2 ) }
    let(:pr4) { GamesDice::Probabilities.for_fair_die( 4 ) }
    let(:pr6) { GamesDice::Probabilities.for_fair_die( 6 ) }
    let(:pr10) { GamesDice::Probabilities.for_fair_die( 10 ) }
    let(:pra) { GamesDice::Probabilities.new( [ 0.4, 0.2, 0.4 ], -1 ) }

    # TODO: each

    describe "#p_eql" do
      it "should return probability of getting a number inside the range" do
        pr2.p_eql(2).should be_within(1.0e-9).of 0.5
        pr4.p_eql(1).should be_within(1.0e-9).of 0.25
        pr6.p_eql(6).should be_within(1.0e-9).of 1.0/6
        pr10.p_eql(3).should be_within(1.0e-9).of 0.1
        pra.p_eql(-1).should be_within(1.0e-9).of 0.4
      end

      it "should return 0.0 for values not covered by distribution" do
        pr2.p_eql(3).should == 0.0
        pr4.p_eql(-1).should == 0.0
        pr6.p_eql(8).should == 0.0
        pr10.p_eql(11).should == 0.0
        pra.p_eql(2).should == 0.0
      end
    end # describe "#p_eql"

    describe "#p_gt" do
      it "should return probability of getting a number greater than target" do
        pr2.p_gt(1).should be_within(1.0e-9).of 0.5
        pr4.p_gt(3).should be_within(1.0e-9).of 0.25
        pr6.p_gt(2).should be_within(1.0e-9).of 4.0/6
        pr10.p_gt(6).should be_within(1.0e-9).of 0.4

        # Trying more than one, due to possibilities of caching error (in pure Ruby implementation)
        pra.p_gt(-2).should be_within(1.0e-9).of 1.0
        pra.p_gt(-1).should be_within(1.0e-9).of 0.6
        pra.p_gt(0).should be_within(1.0e-9).of 0.4
        pra.p_gt(1).should be_within(1.0e-9).of 0.0
      end

      it "should return 0.0 when the target number is equal or higher than maximum possible" do
        pr2.p_gt(2).should == 0.0
        pr4.p_gt(5).should == 0.0
        pr6.p_gt(6).should == 0.0
        pr10.p_gt(20).should == 0.0
        pra.p_gt(3).should == 0.0
      end

      it "should return 1.0 when the target number is lower than minimum" do
        pr2.p_gt(0).should == 1.0
        pr4.p_gt(-5).should == 1.0
        pr6.p_gt(0).should == 1.0
        pr10.p_gt(-200).should == 1.0
        pra.p_gt(-2).should == 1.0
      end
    end # describe "#p_gt"

    describe "#p_ge" do
      it "should return probability of getting a number greater than or equal to target" do
        pr2.p_ge(2).should be_within(1.0e-9).of 0.5
        pr4.p_ge(3).should be_within(1.0e-9).of 0.5
        pr6.p_ge(2).should be_within(1.0e-9).of 5.0/6
        pr10.p_ge(6).should be_within(1.0e-9).of 0.5
      end

      it "should return 0.0 when the target number is higher than maximum possible" do
        pr2.p_ge(6).should == 0.0
        pr4.p_ge(5).should == 0.0
        pr6.p_ge(7).should == 0.0
        pr10.p_ge(20).should == 0.0
      end

      it "should return 1.0 when the target number is lower than or equal to minimum possible" do
        pr2.p_ge(1).should == 1.0
        pr4.p_ge(-5).should == 1.0
        pr6.p_ge(1).should == 1.0
        pr10.p_ge(-200).should == 1.0
      end
    end # describe "#p_ge"

    describe "#p_le" do
      it "should return probability of getting a number less than or equal to target" do
        pr2.p_le(1).should be_within(1.0e-9).of 0.5
        pr4.p_le(2).should be_within(1.0e-9).of 0.5
        pr6.p_le(2).should be_within(1.0e-9).of 2.0/6
        pr10.p_le(6).should be_within(1.0e-9).of 0.6
      end

      it "should return 1.0 when the target number is higher than or equal to maximum possible" do
        pr2.p_le(6).should == 1.0
        pr4.p_le(4).should == 1.0
        pr6.p_le(7).should == 1.0
        pr10.p_le(10).should == 1.0
      end

      it "should return 0.0 when the target number is lower than minimum possible" do
        pr2.p_le(0).should == 0.0
        pr4.p_le(-5).should == 0.0
        pr6.p_le(0).should == 0.0
        pr10.p_le(-200).should == 0.0
      end
    end # describe "#p_le"

    describe "#p_lt" do
      it "should return probability of getting a number less than target" do
        pr2.p_lt(2).should be_within(1.0e-9).of 0.5
        pr4.p_lt(3).should be_within(1.0e-9).of 0.5
        pr6.p_lt(2).should be_within(1.0e-9).of 1/6.0
        pr10.p_lt(6).should be_within(1.0e-9).of 0.5
      end

      it "should return 1.0 when the target number is higher than maximum possible" do
        pr2.p_lt(6).should == 1.0
        pr4.p_lt(5).should == 1.0
        pr6.p_lt(7).should == 1.0
        pr10.p_lt(20).should == 1.0
      end

      it "should return 0.0 when the target number is lower than or equal to minimum possible" do
        pr2.p_lt(1).should == 0.0
        pr4.p_lt(-5).should == 0.0
        pr6.p_lt(1).should == 0.0
        pr10.p_lt(-200).should == 0.0
      end
    end # describe "#p_lt"

    describe "#to_h" do
      # This is used loads in other tests
      it "should represent a valid distribution with each integer result associated with its probability" do
        pr2.to_h.should be_valid_distribution
        pr4.to_h.should be_valid_distribution
        pr6.to_h.should be_valid_distribution
        pr10.to_h.should be_valid_distribution
      end
    end

    describe "#min" do
     it "should return lowest possible result allowed by distribution" do
        pr2.min.should == 1
        pr4.min.should == 1
        pr6.min.should == 1
        pr10.min.should == 1
        GamesDice::Probabilities.add_distributions( pr6, pr10 ).min.should == 2
      end
    end

    describe "#max" do
     it "should return highest possible result allowed by distribution" do
        pr2.max.should == 2
        pr4.max.should == 4
        pr6.max.should == 6
        pr10.max.should == 10
        GamesDice::Probabilities.add_distributions( pr6, pr10 ).max.should == 16
      end
    end

    describe "#expected" do
     it "should return the weighted mean value" do
        pr2.expected.should be_within(1.0e-9).of 1.5
        pr4.expected.should be_within(1.0e-9).of 2.5
        pr6.expected.should be_within(1.0e-9).of 3.5
        pr10.expected.should be_within(1.0e-9).of 5.5
        GamesDice::Probabilities.add_distributions( pr6, pr10 ).expected.should be_within(1.0e-9).of 9.0
      end
    end

    describe "#given_ge" do
     it "should return a new distribution with probabilities calculated assuming value is >= target" do
        pd = pr2.given_ge(2)
        pd.to_h.should == { 2 => 1.0 }
        pd = pr10.given_ge(4)
        pd.to_h.should be_valid_distribution
        pd.p_eql( 3 ).should == 0.0
        pd.p_eql( 10 ).should be_within(1.0e-9).of 0.1/0.7
      end
    end

    describe "#given_le" do
     it "should return a new distribution with probabilities calculated assuming value is <= target" do
        pd = pr2.given_le(2)
        pd.to_h.should == { 1 => 0.5, 2 => 0.5 }
        pd = pr10.given_le(4)
        pd.to_h.should be_valid_distribution
        pd.p_eql( 3 ).should be_within(1.0e-9).of 0.1/0.4
        pd.p_eql( 10 ).should == 0.0
      end
    end

    describe "#repeat_sum" do
      it "should output a valid distribution if params are valid" do
        d4a = GamesDice::Probabilities.new( [ 1.0/4, 1.0/4, 1.0/4, 1.0/4 ], 1 )
        d4b = GamesDice::Probabilities.new( [ 1.0/10, 2.0/10, 3.0/10, 4.0/10], 1 )
        pr = d4a.repeat_sum( 7 )
        pr.to_h.should be_valid_distribution
        pr = d4b.repeat_sum( 12 )
        pr.to_h.should be_valid_distribution
      end

      it "should calculate a '3d6' distribution accurately" do
        d6 = GamesDice::Probabilities.for_fair_die( 6 )
        pr = d6.repeat_sum( 3 )
        h = pr.to_h
        h.should be_valid_distribution
        h[3].should be_within(1e-9).of 1.0/216
        h[4].should be_within(1e-9).of 3.0/216
        h[5].should be_within(1e-9).of 6.0/216
        h[6].should be_within(1e-9).of 10.0/216
        h[7].should be_within(1e-9).of 15.0/216
        h[8].should be_within(1e-9).of 21.0/216
        h[9].should be_within(1e-9).of 25.0/216
        h[10].should be_within(1e-9).of 27.0/216
        h[11].should be_within(1e-9).of 27.0/216
        h[12].should be_within(1e-9).of 25.0/216
        h[13].should be_within(1e-9).of 21.0/216
        h[14].should be_within(1e-9).of 15.0/216
        h[15].should be_within(1e-9).of 10.0/216
        h[16].should be_within(1e-9).of 6.0/216
        h[17].should be_within(1e-9).of 3.0/216
        h[18].should be_within(1e-9).of 1.0/216
      end
    end # describe "#repeat_sum"

    describe "#repeat_n_sum_k" do
      it "should output a valid distribution if params are valid" do
        d4a = GamesDice::Probabilities.new( [ 1.0/4, 1.0/4, 1.0/4, 1.0/4 ], 1 )
        d4b = GamesDice::Probabilities.new( [ 1.0/10, 2.0/10, 3.0/10, 4.0/10], 1 )
        pr = d4a.repeat_n_sum_k( 3, 2 )
        pr.to_h.should be_valid_distribution
        pr = d4b.repeat_n_sum_k( 12, 4 )
        pr.to_h.should be_valid_distribution
      end

      it "should calculate a '4d6 keep best 3' distribution accurately" do
        d6 = GamesDice::Probabilities.for_fair_die( 6 )
        pr = d6.repeat_n_sum_k( 4, 3 )
        h = pr.to_h
        h.should be_valid_distribution
        h[3].should be_within(1e-10).of 1/1296.0
        h[4].should be_within(1e-10).of 4/1296.0
        h[5].should be_within(1e-10).of 10/1296.0
        h[6].should be_within(1e-10).of 21/1296.0
        h[7].should be_within(1e-10).of 38/1296.0
        h[8].should be_within(1e-10).of 62/1296.0
        h[9].should be_within(1e-10).of 91/1296.0
        h[10].should be_within(1e-10).of 122/1296.0
        h[11].should be_within(1e-10).of 148/1296.0
        h[12].should be_within(1e-10).of 167/1296.0
        h[13].should be_within(1e-10).of 172/1296.0
        h[14].should be_within(1e-10).of 160/1296.0
        h[15].should be_within(1e-10).of 131/1296.0
        h[16].should be_within(1e-10).of 94/1296.0
        h[17].should be_within(1e-10).of 54/1296.0
        h[18].should be_within(1e-10).of 21/1296.0
      end

      it "should calculate a '2d20 keep worst result' distribution accurately" do
        d20 = GamesDice::Probabilities.for_fair_die( 20 )
        pr = d20.repeat_n_sum_k( 2, 1, :keep_worst )
        h = pr.to_h
        h.should be_valid_distribution
        h[1].should be_within(1e-10).of 39/400.0
        h[2].should be_within(1e-10).of 37/400.0
        h[3].should be_within(1e-10).of 35/400.0
        h[4].should be_within(1e-10).of 33/400.0
        h[5].should be_within(1e-10).of 31/400.0
        h[6].should be_within(1e-10).of 29/400.0
        h[7].should be_within(1e-10).of 27/400.0
        h[8].should be_within(1e-10).of 25/400.0
        h[9].should be_within(1e-10).of 23/400.0
        h[10].should be_within(1e-10).of 21/400.0
        h[11].should be_within(1e-10).of 19/400.0
        h[12].should be_within(1e-10).of 17/400.0
        h[13].should be_within(1e-10).of 15/400.0
        h[14].should be_within(1e-10).of 13/400.0
        h[15].should be_within(1e-10).of 11/400.0
        h[16].should be_within(1e-10).of 9/400.0
        h[17].should be_within(1e-10).of 7/400.0
        h[18].should be_within(1e-10).of 5/400.0
        h[19].should be_within(1e-10).of 3/400.0
        h[20].should be_within(1e-10).of 1/400.0
      end
    end # describe "#repeat_n_sum_k"

  end # describe "instance methods"
end
