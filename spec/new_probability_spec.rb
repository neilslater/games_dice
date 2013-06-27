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

  end
end
