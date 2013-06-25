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
  end
end
