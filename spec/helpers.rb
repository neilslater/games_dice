# frozen_string_literal: true

# games_dice/spec/helpers.rb
require 'pathname'

require 'games_dice'

def fixture(name)
  "#{__dir__}/fixtures/#{name}"
end

def expect_probability_values(actual, expected, tolerance: 1e-10, tolerances: {}, total_tolerance: 1e-9)
  expected.each do |result, probability|
    matcher = probability.nil? ? be_nil : be_within(tolerances.fetch(result, tolerance)).of(probability)
    expect(actual[result]).to matcher
  end
  expect(actual.values.sum).to be_within(total_tolerance).of(1.0) if total_tolerance
end

def expect_aggregate_probabilities(actual, expected, tolerance: 1e-10)
  expected.each do |query, cases|
    cases.each do |target, probability|
      boundary_probability = probability.zero? || (1.0 - probability).zero?
      matcher = boundary_probability ? eq(probability) : be_within(tolerance).of(probability)
      expect(actual.public_send(query, target)).to matcher
    end
  end
end

def expect_rule_arguments(die_class, keyword, valid:, invalid:)
  valid.each { |value| expect { die_class.new(10, **{ keyword => value }) }.not_to raise_error }
  invalid.each { |value, error| expect { die_class.new(10, **{ keyword => value }) }.to raise_error(error) }
end

def expect_die_result_state(actual, value:, rolls:, reasons:)
  expect(actual.value).to eq(value)
  expect(actual.rolls).to eq(rolls)
  expect(actual.roll_reasons).to eq(reasons)
end

def expect_fair_die(probability_class, sides)
  probability = probability_class.for_fair_die(sides)
  expect(probability).to be_a(probability_class)
  expect_fair_distribution(probability.to_h, sides)
end

def expect_fair_distribution(distribution, sides)
  expected = (1..sides).to_h { |result| [result, 1.0 / sides] }
  expect(distribution).to be_valid_distribution
  expect(distribution.keys).to match_array(expected.keys)
  expect_probability_values(distribution, expected, total_tolerance: nil)
end

def expect_injected_prng(die, prng)
  (0..5).each do |die_result|
    allow(prng).to receive(:rand).and_return(die_result)
    expect(die.roll).to eq((die_result + 1) * 3)
    expect(prng).to have_received(:rand).with(6).at_least(:once)
  end
end

def seeded_rolls(factory, notation, seed:, count:)
  srand(seed)
  die = factory.create(notation)
  Array.new(count) { die.roll }
end

# TestPRNG tests short predictable series
class TestPRNG
  def initialize
    @numbers = [0.123, 0.234, 0.345, 0.999, 0.876, 0.765, 0.543, 0.111, 0.333, 0.777]
  end

  def rand(num)
    Integer(num * @numbers.pop)
  end
end

# TestPRNGMax checks behaviour of re-rolls
class TestPRNGMax
  def rand(num)
    Integer(num) - 1
  end
end

# TestPRNGMin checks behaviour of re-rolls
class TestPRNGMin
  def rand(_num)
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
    if !given.is_a?(Hash)
      @error = "distribution should be a Hash, but it is a #{given.class}"
    elsif given.keys.any? { |k| !k.is_a?(Integer) }
      bad_key = given.keys.first { |k| !k.is_a?(Integer) }
      @error = "all keys should be Integers, but found '#{bad_key.inspect}' which is a #{bad_key.class}"
    elsif given.values.any? { |v| !v.is_a?(Float) }
      bad_value = given.values.find { |v| !v.is_a?(Float) }
      @error = "all values should be Floats, but found '#{bad_value.inspect}' which is a #{bad_value.class}"
    elsif given.values.any? { |v| v < 0.0 || v > 1.0 }
      bad_value = given.values.find { |v| v < 0.0 || v > 1.0 }
      @error = "all values should be in range (0.0..1.0), but found #{bad_value}"
    elsif (1.0 - given.values.sum).abs > 1e-6
      total_probs = given.values.sum
      @error = "sum of values should be 1.0, but got #{total_probs}"
    end
    !@error
  end

  failure_message do |_given|
    @error || 'Distribution is valid and complete'
  end

  failure_message_when_negated do |_given|
    @error || 'Distribution is valid and complete'
  end

  description do |_given|
    'a hash describing a complete probability distribution of integer results'
  end
end
