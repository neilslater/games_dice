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
    let(:pa) { GamesDice::Probabilities.new( { -1 => 0.4, 0 => 0.2, 1 => 0.4 } ) }

    describe "#p_eql" do
      it "should return probability of getting a number inside the range" do
        p2.p_eql(2).should be_within(1.0e-9).of 0.5
        p4.p_eql(1).should be_within(1.0e-9).of 0.25
        p6.p_eql(6).should be_within(1.0e-9).of 1.0/6
        p10.p_eql(3).should be_within(1.0e-9).of 0.1
        pa.p_eql(-1).should be_within(1.0e-9).of 0.4
      end

      it "should return 0.0 for values not covered by distribution" do
        p2.p_eql(3).should == 0.0
        p4.p_eql(-1).should == 0.0
        p6.p_eql(8).should == 0.0
        p10.p_eql(11).should == 0.0
        pa.p_eql(2).should == 0.0
      end
    end # describe "#p_eql"

    describe "#p_gt" do
      it "should return probability of getting a number greater than target" do
        p2.p_gt(1).should be_within(1.0e-9).of 0.5
        p4.p_gt(3).should be_within(1.0e-9).of 0.25
        p6.p_gt(2).should be_within(1.0e-9).of 4.0/6
        p10.p_gt(6).should be_within(1.0e-9).of 0.4

        # Trying more than one, due to unusual error seen in complex_die_spec when calculating probabilities
        pa.p_gt(-2).should be_within(1.0e-9).of 1.0
        pa.p_gt(-1).should be_within(1.0e-9).of 0.6
        pa.p_gt(0).should be_within(1.0e-9).of 0.4
        pa.p_gt(1).should be_within(1.0e-9).of 0.0
      end

      it "should return 0.0 when the target number is equal or higher than maximum possible" do
        p2.p_gt(2).should == 0.0
        p4.p_gt(5).should == 0.0
        p6.p_gt(6).should == 0.0
        p10.p_gt(20).should == 0.0
        pa.p_gt(3).should == 0.0
      end

      it "should return 1.0 when the target number is lower than minimum" do
        p2.p_gt(0).should == 1.0
        p4.p_gt(-5).should == 1.0
        p6.p_gt(0).should == 1.0
        p10.p_gt(-200).should == 1.0
        pa.p_gt(-2).should == 1.0
      end
    end # describe "#p_gt"

    describe "#p_ge" do
      it "should return probability of getting a number greater than or equal to target" do
        p2.p_ge(2).should be_within(1.0e-9).of 0.5
        p4.p_ge(3).should be_within(1.0e-9).of 0.5
        p6.p_ge(2).should be_within(1.0e-9).of 5.0/6
        p10.p_ge(6).should be_within(1.0e-9).of 0.5
      end

      it "should return 0.0 when the target number is higher than maximum possible" do
        p2.p_ge(6).should == 0.0
        p4.p_ge(5).should == 0.0
        p6.p_ge(7).should == 0.0
        p10.p_ge(20).should == 0.0
      end

      it "should return 1.0 when the target number is lower than or equal to minimum possible" do
        p2.p_ge(1).should == 1.0
        p4.p_ge(-5).should == 1.0
        p6.p_ge(1).should == 1.0
        p10.p_ge(-200).should == 1.0
      end
    end # describe "#p_ge"

    describe "#p_le" do
      it "should return probability of getting a number less than or equal to target" do
        p2.p_le(1).should be_within(1.0e-9).of 0.5
        p4.p_le(2).should be_within(1.0e-9).of 0.5
        p6.p_le(2).should be_within(1.0e-9).of 2.0/6
        p10.p_le(6).should be_within(1.0e-9).of 0.6
      end

      it "should return 1.0 when the target number is higher than or equal to maximum possible" do
        p2.p_le(6).should == 1.0
        p4.p_le(4).should == 1.0
        p6.p_le(7).should == 1.0
        p10.p_le(10).should == 1.0
      end

      it "should return 0.0 when the target number is lower than minimum possible" do
        p2.p_le(0).should == 0.0
        p4.p_le(-5).should == 0.0
        p6.p_le(0).should == 0.0
        p10.p_le(-200).should == 0.0
      end
    end # describe "#p_le"

    describe "#p_lt" do
      it "should return probability of getting a number less than target" do
        p2.p_lt(2).should be_within(1.0e-9).of 0.5
        p4.p_lt(3).should be_within(1.0e-9).of 0.5
        p6.p_lt(2).should be_within(1.0e-9).of 1/6.0
        p10.p_lt(6).should be_within(1.0e-9).of 0.5
      end

      it "should return 1.0 when the target number is higher than maximum possible" do
        p2.p_lt(6).should == 1.0
        p4.p_lt(5).should == 1.0
        p6.p_lt(7).should == 1.0
        p10.p_lt(20).should == 1.0
      end

      it "should return 0.0 when the target number is lower than or equal to minimum possible" do
        p2.p_lt(1).should == 0.0
        p4.p_lt(-5).should == 0.0
        p6.p_lt(1).should == 0.0
        p10.p_lt(-200).should == 0.0
      end
    end # describe "#p_lt"

    describe "#to_h" do
      # This is used loads in other tests
      it "should represent a valid distribution with each integer result associated with its probability" do
        p2.to_h.should be_valid_distribution
        p4.to_h.should be_valid_distribution
        p6.to_h.should be_valid_distribution
        p10.to_h.should be_valid_distribution
      end
    end

    describe "#min" do
     it "should return lowest possible result allowed by distribution" do
        p2.min.should == 1
        p4.min.should == 1
        p6.min.should == 1
        p10.min.should == 1
        GamesDice::Probabilities.add_distributions( p6, p10 ).min.should == 2
      end
    end

    describe "#max" do
     it "should return highest possible result allowed by distribution" do
        p2.max.should == 2
        p4.max.should == 4
        p6.max.should == 6
        p10.max.should == 10
        GamesDice::Probabilities.add_distributions( p6, p10 ).max.should == 16
      end
    end

    describe "#expected" do
     it "should return the weighted mean value" do
        p2.expected.should be_within(1.0e-9).of 1.5
        p4.expected.should be_within(1.0e-9).of 2.5
        p6.expected.should be_within(1.0e-9).of 3.5
        p10.expected.should be_within(1.0e-9).of 5.5
        GamesDice::Probabilities.add_distributions( p6, p10 ).expected.should be_within(1.0e-9).of 9.0
      end
    end

  end # describe "instance methods"

end