require 'games_dice'

# A valid distribution is:
#  A hash
#  Keys are all Integers
#  Values are all positive Floats, between 0.0 and 1.0
#  Sum of values is 1.0
RSpec::Matchers.define :be_valid_distribution do
  match do |given|
    @error = nil
    if ! given.is_a?(Hash)
      @error = "distribution should be a Hash, but it is a #{given.class}"
    elsif given.keys.any? { |k| ! k.is_a?(Fixnum) }
      bad_key = given.keys.first { |k| ! k.is_a?(Fixnum) }
      @error = "all keys should be Fixnums, but found '#{bad_key.inspect}' which is a #{bad_key.class}"
    elsif given.values.any? { |v| ! v.is_a?(Float) }
      bad_value = given.values.first { |v| ! v.is_a?(Float) }
      @error = "all values should be Floats, but found '#{bad_value.inspect}' which is a #{bad_value.class}"
    elsif given.values.any? { |v| v < 0.0 || v > 1.0 }
      bad_value = given.values.first { |v| v < 0.0 || v > 1.0 }
      @error = "all values should be in range (0.0..1.0), but found #{bad_value}"
    elsif (1.0 - given.values.inject(:+)).abs > 1e-6
      total_probs = given.values.inject(:+)
      @error = "sum of values should be 1.0, but got #{total_probs}"
    end
    ! @error
  end

  failure_message_for_should do |given|
    @error ? @error : 'Distribution is valid and complete'
  end

  failure_message_for_should_not do |given|
     @error ? @error : 'Distribution is valid and complete'
  end

  description do |given|
    "a hash describing a complete discrete probability distribution of integers"
  end
end

describe GamesDice::Probabilities do

  describe "class methods" do

    describe "#new" do
      it "should create a new distribution from a hash" do
        p = GamesDice::Probabilities.new( { 1 => 1.0 } )
        p.is_a?( GamesDice::Probabilities ).should be_true
        p.to_h.should be_valid_distribution
      end
    end

    describe "#for_fair_die" do
      it "should create a new distribution based on number of sides" do
        p2 = GamesDice::Probabilities.for_fair_die( 2 )
        p2.is_a?( GamesDice::Probabilities ).should be_true
        p2.to_h.should == { 1 => 0.5, 2 => 0.5 }
        (1..20).each do |sides|
          p = GamesDice::Probabilities.for_fair_die( sides )
          p.is_a?( GamesDice::Probabilities ).should be_true
          h = p.to_h
          h.should be_valid_distribution
          h.keys.count.should == sides
          h.values.each { |v| v.should be_within(1e-10).of 1.0/sides }
        end
      end
    end

    describe "#add_distributions" do
      it "should combine two distributions to create a third one" do
        d4a = GamesDice::Probabilities.new( { 1 => 1.0/4, 2 => 1.0/4, 3 => 1.0/4, 4 => 1.0/4 } )
        d4b = GamesDice::Probabilities.new( { 1 => 1.0/10, 2 => 2.0/10, 3 => 3.0/10, 4 => 4.0/10 } )
        p = GamesDice::Probabilities.add_distributions( d4a, d4b )
        p.to_h.should be_valid_distribution
      end

      it "should calculate a classic 2d6 distribution accurately" do
        d6 = GamesDice::Probabilities.for_fair_die( 6 )
        p = GamesDice::Probabilities.add_distributions( d6, d6 )
        p.to_h.should be_valid_distribution
        p.to_h[2].should be_within(1e-9).of 1.0/36
        p.to_h[3].should be_within(1e-9).of 2.0/36
        p.to_h[4].should be_within(1e-9).of 3.0/36
        p.to_h[5].should be_within(1e-9).of 4.0/36
        p.to_h[6].should be_within(1e-9).of 5.0/36
        p.to_h[7].should be_within(1e-9).of 6.0/36
        p.to_h[8].should be_within(1e-9).of 5.0/36
        p.to_h[9].should be_within(1e-9).of 4.0/36
        p.to_h[10].should be_within(1e-9).of 3.0/36
        p.to_h[11].should be_within(1e-9).of 2.0/36
        p.to_h[12].should be_within(1e-9).of 1.0/36
      end
    end

  end # describe "class methods"

  describe "instance methods" do
    let(:p2) { GamesDice::Probabilities.for_fair_die( 2 ) }
    let(:p4) { GamesDice::Probabilities.for_fair_die( 4 ) }
    let(:p6) { GamesDice::Probabilities.for_fair_die( 6 ) }
    let(:p10) { GamesDice::Probabilities.for_fair_die( 10 ) }

    describe "#p_eql" do
      it "should return probability of getting a number inside the range" do
        p2.p_eql(2).should be_within(1.0e-9).of 0.5
        p4.p_eql(1).should be_within(1.0e-9).of 0.25
        p6.p_eql(6).should be_within(1.0e-9).of 1.0/6
        p10.p_eql(3).should be_within(1.0e-9).of 0.1
      end

      it "should return 0.0 for values not covered by distribution" do
        p2.p_eql(3).should == 0.0
        p4.p_eql(-1).should == 0.0
        p6.p_eql(8).should == 0.0
        p10.p_eql(11).should == 0.0
      end
    end # describe "#p_eql"

    describe "#p_gt" do
      it "should return probability of getting a number greater than target" do
        p2.p_gt(1).should be_within(1.0e-9).of 0.5
        p4.p_gt(3).should be_within(1.0e-9).of 0.25
        p6.p_gt(2).should be_within(1.0e-9).of 4.0/6
        p10.p_gt(6).should be_within(1.0e-9).of 0.4
      end

      it "should return 0.0 when the target number is equal or higher than maximum possible" do
        p2.p_gt(2).should == 0.0
        p4.p_gt(5).should == 0.0
        p6.p_gt(6).should == 0.0
        p10.p_gt(20).should == 0.0
      end

      it "should return 1.0 when the target number is lower than minimum" do
        p2.p_gt(0).should == 1.0
        p4.p_gt(-5).should == 1.0
        p6.p_gt(0).should == 1.0
        p10.p_gt(-200).should == 1.0
      end
    end # describe "#p_gt"

  end # describe "instance methods"

end
