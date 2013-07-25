require 'helpers'

describe GamesDice::MapRule do

  describe "#new" do

    it "should accept self-consistent operator/value pairs as a trigger" do
      GamesDice::MapRule.new( 5, :>, 1 )
      GamesDice::MapRule.new( (1..5), :member?, 17 )
    end

    it "should reject inconsistent operator/value pairs for a trigger" do
      lambda { GamesDice::MapRule.new( 5, :member?, -1 ) }.should raise_error( ArgumentError )
      lambda { GamesDice::MapRule.new( (1..5), :>, 12 ) }.should raise_error( ArgumentError )
    end

    it "should reject non-Integer map results" do
      lambda { GamesDice::MapRule.new( 5, :>, :reroll_again ) }.should raise_error( TypeError )
      lambda { GamesDice::MapRule.new( (1..5), :member?, 'foo' ) }.should raise_error( TypeError )
    end

  end

  describe '#map_from' do

    it "should return the mapped value for a match" do
      rule = GamesDice::MapRule.new( 5, :>, -1 )
      rule.map_from(4).should == -1

      rule = GamesDice::MapRule.new( (1..5), :member?, 3 )
      rule.map_from(4).should == 3
    end

    it "should return false for no match" do
      rule = GamesDice::MapRule.new( 5, :>, -1 )
      rule.map_from(6).should be_false

      rule = GamesDice::MapRule.new( (1..5), :member?, 3 )
      rule.map_from(6).should be_false
    end

  end

end