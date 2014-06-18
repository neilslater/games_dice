require 'helpers'

describe GamesDice::RerollRule do

  describe "#new" do

    it "should accept self-consistent operator/value pairs as a trigger" do
      GamesDice::RerollRule.new( 5, :>, :reroll_subtract )
      GamesDice::RerollRule.new( (1..5), :member?, :reroll_replace )
    end

    it "should reject inconsistent operator/value pairs for a trigger" do
      lambda { GamesDice::RerollRule.new( 5, :member?, :reroll_subtract ) }.should raise_error( ArgumentError )
      lambda { GamesDice::RerollRule.new( (1..5), :>, :reroll_replace ) }.should raise_error( ArgumentError )
    end

    it "should reject bad re-roll types" do
      lambda { GamesDice::RerollRule.new( 5, :>, :reroll_again ) }.should raise_error( ArgumentError )
      lambda { GamesDice::RerollRule.new( (1..5), :member?, 42 ) }.should raise_error( ArgumentError )
    end

  end

  describe '#applies?' do

    it "should return true if a trigger condition is met" do
      rule = GamesDice::RerollRule.new( 5, :>, :reroll_subtract )
      rule.applies?(4).should == true

      rule = GamesDice::RerollRule.new( (1..5), :member?, :reroll_subtract )
      rule.applies?(4).should == true
    end

    it "should return false if a trigger condition is not met" do
      rule = GamesDice::RerollRule.new( 5, :>, :reroll_subtract )
      rule.applies?(7).should == false

      rule = GamesDice::RerollRule.new( (1..5), :member?, :reroll_subtract )
      rule.applies?(6).should == false
    end

  end

end