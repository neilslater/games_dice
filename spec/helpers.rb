# games_dice/spec/helpers.rb
require 'pathname'
require 'coveralls'
Coveralls.wear!

require 'games_dice'


def fixture name
  (Pathname.new(__FILE__).dirname + "fixtures" + name).to_s
end

# TestPRNG tests short predictable series
class TestPRNG
  def initialize
    @numbers = [0.123,0.234,0.345,0.999,0.876,0.765,0.543,0.111,0.333,0.777]
  end
  def rand(n)
    Integer( n * @numbers.pop )
  end
end

# TestPRNGMax checks behaviour of re-rolls
class TestPRNGMax
  def rand(n)
    Integer( n ) - 1
  end
end

# TestPRNGMin checks behaviour of re-rolls
class TestPRNGMin
  def rand(n)
    1
  end
end

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
      bad_value = given.values.find { |v| ! v.is_a?(Float) }
      @error = "all values should be Floats, but found '#{bad_value.inspect}' which is a #{bad_value.class}"
    elsif given.values.any? { |v| v < 0.0 || v > 1.0 }
      bad_value = given.values.find { |v| v < 0.0 || v > 1.0 }
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
    "a hash describing a complete probability distribution of integer results"
  end
end
