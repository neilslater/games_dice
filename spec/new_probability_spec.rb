require 'games_dice'
require 'helpers'

describe GamesDice::NewProbabilities do
  describe "class methods" do
    describe "#new" do
      it "should create a new distribution from an array and offset" do
        p = GamesDice::NewProbabilities.new( [1.0], 1 )
        p.is_a?( GamesDice::NewProbabilities ).should be_true
        p.to_h.should be_valid_distribution
      end
    end

    describe "#for_fair_die" do
      it "should create a new distribution based on number of sides" do
        p2 = GamesDice::NewProbabilities.for_fair_die( 2 )
        p2.is_a?( GamesDice::NewProbabilities ).should be_true
        p2.to_h.should == { 1 => 0.5, 2 => 0.5 }
        (1..20).each do |sides|
          p = GamesDice::NewProbabilities.for_fair_die( sides )
          p.is_a?( GamesDice::NewProbabilities ).should be_true
          h = p.to_h
          h.should be_valid_distribution
          h.keys.count.should == sides
          h.values.each { |v| v.should be_within(1e-10).of 1.0/sides }
        end
      end
    end

    describe "#add_distributions" do
      it "should combine two distributions to create a third one" do
        d4a = GamesDice::NewProbabilities.new( [ 1.0/4, 1.0/4, 1.0/4, 1.0/4 ], 1 )
        d4b = GamesDice::NewProbabilities.new( [ 1.0/10, 2.0/10, 3.0/10, 4.0/10], 1 )
        p = GamesDice::NewProbabilities.add_distributions( d4a, d4b )
        p.to_h.should be_valid_distribution
      end

      it "should calculate a classic 2d6 distribution accurately" do
        d6 = GamesDice::NewProbabilities.for_fair_die( 6 )
        p = GamesDice::NewProbabilities.add_distributions( d6, d6 )
        h = p.to_h
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
        d4a = GamesDice::NewProbabilities.new( [ 1.0/4, 1.0/4, 1.0/4, 1.0/4 ], 1 )
        d4b = GamesDice::NewProbabilities.new( [ 1.0/10, 2.0/10, 3.0/10, 4.0/10], 1 )
        p = GamesDice::NewProbabilities.add_distributions_mult( 2, d4a, -1, d4b )
        p.to_h.should be_valid_distribution
      end

      it "should calculate a distribution for '1d6 - 1d4' accurately" do
        d6 = GamesDice::NewProbabilities.for_fair_die( 6 )
        d4 = GamesDice::NewProbabilities.for_fair_die( 4 )
        p = GamesDice::NewProbabilities.add_distributions_mult( 1, d6, -1, d4 )
        h = p.to_h
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
    end

  end
end
