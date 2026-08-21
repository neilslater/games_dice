# frozen_string_literal: true

require 'helpers'
require 'objspace'

describe GamesDice::Probabilities, :aggregate_failures do
  let(:distributions) do
    {
      two: described_class.for_fair_die(2), four: described_class.for_fair_die(4),
      six: described_class.for_fair_die(6), ten: described_class.for_fair_die(10),
      twenty: described_class.for_fair_die(20), uniform_four: described_class.new([0.25, 0.25, 0.25, 0.25], 1),
      weighted_four: described_class.new([0.1, 0.2, 0.3, 0.4], 1),
      left_asymmetric: described_class.new([0.7, 0.0, 0.3], 2),
      right_asymmetric: described_class.new([0.5, 0.3, 0.2], 2),
      offset_asymmetric: described_class.new([0.4, 0.2, 0.4], -1)
    }
  end

  def distribution(name)
    distributions.fetch(name)
  end

  describe 'class methods' do
    describe '#new' do
      it 'create a new distribution from an array and offset' do
        pr = described_class.new([1.0], 1)
        expect(pr).to be_a described_class
        expect(pr.to_h).to be_valid_distribution
      end

      it 'raise an error if passed incorrect parameter types' do
        expect { described_class.new([nil], 20) }.to raise_error TypeError
        expect { described_class.new([0.3, nil, 0.5], 7) }.to raise_error TypeError
        expect { described_class.new([0.3, 0.2, 0.5], {}) }.to raise_error TypeError
        expect { described_class.new({ x: :y }, 17) }.to raise_error TypeError
      end

      it 'raise an error if distribution is incomplete or inaccurate' do
        expect { described_class.new([0.3, 0.2, 0.6], 3) }.to raise_error ArgumentError
        expect { described_class.new([], 1) }.to raise_error ArgumentError
        expect { described_class.new([0.9], 1) }.to raise_error ArgumentError
        expect { described_class.new([-0.9, 0.2, 0.9], 1) }.to raise_error ArgumentError
        expect { described_class.new([1.1], 1) }.to raise_error ArgumentError
      end
    end

    describe '#for_fair_die' do
      it 'create a new distribution based on number of sides' do
        (1..20).each { |sides| expect_fair_die(described_class, sides) }
      end

      it 'raise an error if number of sides is not an integer' do
        expect { described_class.for_fair_die({}) }.to raise_error TypeError
      end

      it 'raise an error if number of sides is too low or too high' do
        expect { described_class.for_fair_die(0) }.to raise_error ArgumentError
        expect { described_class.for_fair_die(1_000_001) }.to raise_error ArgumentError
      end
    end

    describe '#add_distributions' do
      it 'combine two distributions to create a third one' do
        d4a = described_class.new([1.0 / 4, 1.0 / 4, 1.0 / 4, 1.0 / 4], 1)
        d4b = described_class.new([1.0 / 10, 2.0 / 10, 3.0 / 10, 4.0 / 10], 1)
        pr = described_class.add_distributions(d4a, d4b)
        expect(pr.to_h).to be_valid_distribution
      end

      it 'calculate a classic 2d6 distribution accurately' do
        h = described_class.add_distributions(distribution(:six), distribution(:six)).to_h
        expect(h).to be_valid_distribution
        expected = (2..12).to_h { |result| [result, (6 - (7 - result).abs) / 36.0] }
        expect_probability_values(h, expected, tolerance: 1e-9, total_tolerance: nil)
      end

      it 'raise an error if either parameter is not a GamesDice::Probabilities object' do
        d10 = described_class.for_fair_die(10)
        expect { described_class.add_distributions('', 6) }.to raise_error TypeError
        expect { described_class.add_distributions(d10, 6) }.to raise_error TypeError
        expect { described_class.add_distributions('', d10) }.to raise_error TypeError
      end
    end

    describe '#add_distributions_mult' do
      it 'combine two multiplied distributions to create a third one' do
        d4a = described_class.new([1.0 / 4, 1.0 / 4, 1.0 / 4, 1.0 / 4], 1)
        d4b = described_class.new([1.0 / 10, 2.0 / 10, 3.0 / 10, 4.0 / 10], 1)
        pr = described_class.add_distributions_mult(2, d4a, -1, d4b)
        expect(pr.to_h).to be_valid_distribution
      end

      it "calculate a distribution for '1d6 - 1d4' accurately" do
        h = described_class.add_distributions_mult(1, distribution(:six), -1, distribution(:four)).to_h
        expect(h).to be_valid_distribution
        numerators = [1, 2, 3, 4, 4, 4, 3, 2, 1]
        expected = (-3..5).zip(numerators.map { |numerator| numerator / 24.0 }).to_h
        expect_probability_values(h, expected, tolerance: 1e-9, total_tolerance: nil)
      end

      it 'add asymmetric distributions accurately' do
        h = described_class.add_distributions_mult(1, distribution(:left_asymmetric), 2,
                                                   distribution(:right_asymmetric)).to_h
        expect(h).to be_valid_distribution
        expected = { 6 => 0.7 * 0.5, 8 => (0.7 * 0.3) + (0.3 * 0.5),
                     10 => (0.7 * 0.2) + (0.3 * 0.3), 12 => 0.3 * 0.2 }
        expect_probability_values(h, expected, tolerance: 1e-9, total_tolerance: nil)
      end

      it 'raise an error if passed incorrect objects for distributions' do
        d10 = described_class.for_fair_die(10)
        expect { described_class.add_distributions_mult(1, '', -1, 6) }.to raise_error TypeError
        expect { described_class.add_distributions_mult(2, d10, 3, 6) }.to raise_error TypeError
        expect { described_class.add_distributions_mult(1, '', -1, d10) }.to raise_error TypeError
      end

      it 'raise an error if passed incorrect objects for multipliers' do
        d10 = described_class.for_fair_die(10)
        expect { described_class.add_distributions_mult({}, d10, [], d10) }.to raise_error TypeError
        expect { described_class.add_distributions_mult([7], d10, 3, d10) }.to raise_error TypeError
        expect { described_class.add_distributions_mult(1, d10, {}, d10) }.to raise_error TypeError
      end
    end

    describe '#from_h' do
      it 'create a Probabilities object from a valid hash' do
        pr = described_class.from_h({ 7 => 0.5, 9 => 0.5 })
        expect(pr).to be_a described_class
      end

      it 'create the same distribution when hash keys descend' do
        pr = described_class.from_h({ 9 => 0.5, 7 => 0.5 })
        expect(pr.to_h).to eql({ 7 => 0.5, 9 => 0.5 })
      end

      it 'raise an ArgumentError when called with a non-valid hash' do
        expect { described_class.from_h({ 7 => 0.5, 9 => 0.6 }) }.to raise_error ArgumentError
        expect { described_class.from_h({ 7 => 0.4, 9 => 0.5 }) }.to raise_error ArgumentError
      end

      it 'raise an TypeError when called with data that is not a hash' do
        expect { described_class.from_h(:foo) }.to raise_error TypeError
      end

      it 'raise a TypeError when called when keys and values are not all integers and floats' do
        expect { described_class.from_h({ 'x' => 0.5, 9 => 0.5 }) }.to raise_error TypeError
        expect { described_class.from_h({ 7 => [], 9 => 0.5 }) }.to raise_error TypeError
      end

      it 'raise an ArgumentError when results are spread very far apart' do
        expect { described_class.from_h({ 0 => 0.5, 2_000_000 => 0.5 }) }.to raise_error ArgumentError
      end
    end
  end

  describe 'instance methods' do
    describe '#clone' do
      it 'create an independent object with the same distribution' do
        copy = distribution(:offset_asymmetric).clone
        expect(copy).not_to equal(distribution(:offset_asymmetric))
        expect(copy.to_h).to eql(distribution(:offset_asymmetric).to_h)
      end
    end

    describe 'native memory accounting' do
      it 'include allocated probability arrays' do
        empty = described_class.allocate
        expect(ObjectSpace.memsize_of(distribution(:ten))).to be > ObjectSpace.memsize_of(empty)
      end
    end

    describe '#each' do
      it 'iterate through all result/probability pairs' do
        yielded = distribution(:four).to_enum.map { |result, probability| [result, probability] }
        expect(yielded).to eql [[1, 0.25], [2, 0.25], [3, 0.25], [4, 0.25]]
      end

      it 'skip zero probabilities' do
        pr_plus_minus = described_class.new([0.5, 0.0, 0.5], -1)
        yielded = pr_plus_minus.to_enum.map { |result, probability| [result, probability] }
        expect(yielded).to eql [[-1, 0.5], [1, 0.5]]
      end
    end

    describe '#p_eql' do
      it 'return probability of getting a number inside the range' do
        expect(distribution(:two).p_eql(2)).to be_within(1.0e-9).of 0.5
        expect(distribution(:four).p_eql(1)).to be_within(1.0e-9).of 0.25
        expect(distribution(:six).p_eql(6)).to be_within(1.0e-9).of 1.0 / 6
        expect(distribution(:ten).p_eql(3)).to be_within(1.0e-9).of 0.1
        expect(distribution(:offset_asymmetric).p_eql(-1)).to be_within(1.0e-9).of 0.4
      end

      it 'return 0.0 for values not covered by distribution' do
        expect(distribution(:two).p_eql(3)).to be 0.0
        expect(distribution(:four).p_eql(-1)).to be 0.0
        expect(distribution(:six).p_eql(8)).to be 0.0
        expect(distribution(:ten).p_eql(11)).to be 0.0
        expect(distribution(:offset_asymmetric).p_eql(2)).to be 0.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { distribution(:two).p_eql([]) }.to raise_error TypeError
      end
    end

    describe '#p_gt' do
      it 'return probability of getting a number greater than target' do
        # Trying more than one, due to possibilities of caching error (in pure Ruby implementation)
        cases = [[distribution(:two), 1, 0.5], [distribution(:four), 3, 0.25],
                 [distribution(:six), 2, 4.0 / 6], [distribution(:ten), 6, 0.4],
                 [distribution(:offset_asymmetric), -2, 1.0],
                 [distribution(:offset_asymmetric), -1, 0.6], [distribution(:offset_asymmetric), 0, 0.4],
                 [distribution(:offset_asymmetric), 1, 0.0]]
        cases.each { |probability, target, expected| expect(probability.p_gt(target)).to be_within(1e-9).of(expected) }
      end

      it 'return 0.0 when the target number is equal or higher than maximum possible' do
        expect(distribution(:two).p_gt(2)).to be 0.0
        expect(distribution(:four).p_gt(5)).to be 0.0
        expect(distribution(:six).p_gt(6)).to be 0.0
        expect(distribution(:ten).p_gt(20)).to be 0.0
        expect(distribution(:offset_asymmetric).p_gt(3)).to be 0.0
      end

      it 'return 1.0 when the target number is lower than minimum' do
        expect(distribution(:two).p_gt(0)).to be 1.0
        expect(distribution(:four).p_gt(-5)).to be 1.0
        expect(distribution(:six).p_gt(0)).to be 1.0
        expect(distribution(:ten).p_gt(-200)).to be 1.0
        expect(distribution(:offset_asymmetric).p_gt(-2)).to be 1.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { distribution(:two).p_gt({}) }.to raise_error TypeError
      end
    end

    describe '#p_ge' do
      it 'return probability of getting a number greater than or equal to target' do
        expect(distribution(:two).p_ge(2)).to be_within(1.0e-9).of 0.5
        expect(distribution(:four).p_ge(3)).to be_within(1.0e-9).of 0.5
        expect(distribution(:six).p_ge(2)).to be_within(1.0e-9).of 5.0 / 6
        expect(distribution(:ten).p_ge(6)).to be_within(1.0e-9).of 0.5
      end

      it 'return 0.0 when the target number is higher than maximum possible' do
        expect(distribution(:two).p_ge(6)).to be 0.0
        expect(distribution(:four).p_ge(5)).to be 0.0
        expect(distribution(:six).p_ge(7)).to be 0.0
        expect(distribution(:ten).p_ge(20)).to be 0.0
      end

      it 'return 1.0 when the target number is lower than or equal to minimum possible' do
        expect(distribution(:two).p_ge(1)).to be 1.0
        expect(distribution(:four).p_ge(-5)).to be 1.0
        expect(distribution(:six).p_ge(1)).to be 1.0
        expect(distribution(:ten).p_ge(-200)).to be 1.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { distribution(:four).p_ge({}) }.to raise_error TypeError
      end
    end

    describe '#p_le' do
      it 'return probability of getting a number less than or equal to target' do
        expect(distribution(:two).p_le(1)).to be_within(1.0e-9).of 0.5
        expect(distribution(:four).p_le(2)).to be_within(1.0e-9).of 0.5
        expect(distribution(:six).p_le(2)).to be_within(1.0e-9).of 2.0 / 6
        expect(distribution(:ten).p_le(6)).to be_within(1.0e-9).of 0.6
      end

      it 'return 1.0 when the target number is higher than or equal to maximum possible' do
        expect(distribution(:two).p_le(6)).to be 1.0
        expect(distribution(:four).p_le(4)).to be 1.0
        expect(distribution(:six).p_le(7)).to be 1.0
        expect(distribution(:ten).p_le(10)).to be 1.0
      end

      it 'return 0.0 when the target number is lower than minimum possible' do
        expect(distribution(:two).p_le(0)).to be 0.0
        expect(distribution(:four).p_le(-5)).to be 0.0
        expect(distribution(:six).p_le(0)).to be 0.0
        expect(distribution(:ten).p_le(-200)).to be 0.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { distribution(:four).p_le([]) }.to raise_error TypeError
      end
    end

    describe '#p_lt' do
      it 'return probability of getting a number less than target' do
        expect(distribution(:two).p_lt(2)).to be_within(1.0e-9).of 0.5
        expect(distribution(:four).p_lt(3)).to be_within(1.0e-9).of 0.5
        expect(distribution(:six).p_lt(2)).to be_within(1.0e-9).of 1 / 6.0
        expect(distribution(:ten).p_lt(6)).to be_within(1.0e-9).of 0.5
      end

      it 'return 1.0 when the target number is higher than maximum possible' do
        expect(distribution(:two).p_lt(6)).to be 1.0
        expect(distribution(:four).p_lt(5)).to be 1.0
        expect(distribution(:six).p_lt(7)).to be 1.0
        expect(distribution(:ten).p_lt(20)).to be 1.0
      end

      it 'return 0.0 when the target number is lower than or equal to minimum possible' do
        expect(distribution(:two).p_lt(1)).to be 0.0
        expect(distribution(:four).p_lt(-5)).to be 0.0
        expect(distribution(:six).p_lt(1)).to be 0.0
        expect(distribution(:ten).p_lt(-200)).to be 0.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { distribution(:six).p_lt({}) }.to raise_error TypeError
      end
    end

    describe '#to_h' do
      # This is used loads in other tests
      it 'represent a valid distribution with each integer result associated with its probability' do
        expect(distribution(:two).to_h).to be_valid_distribution
        expect(distribution(:four).to_h).to be_valid_distribution
        expect(distribution(:six).to_h).to be_valid_distribution
        expect(distribution(:ten).to_h).to be_valid_distribution
      end
    end

    describe '#min' do
      it 'return lowest possible result allowed by distribution' do
        expect(distribution(:two).min).to be 1
        expect(distribution(:four).min).to be 1
        expect(distribution(:six).min).to be 1
        expect(distribution(:ten).min).to be 1
        expect(described_class.add_distributions(distribution(:six), distribution(:ten)).min).to be 2
      end
    end

    describe '#max' do
      it 'return highest possible result allowed by distribution' do
        expect(distribution(:two).max).to be 2
        expect(distribution(:four).max).to be 4
        expect(distribution(:six).max).to be 6
        expect(distribution(:ten).max).to be 10
        expect(described_class.add_distributions(distribution(:six), distribution(:ten)).max).to be 16
      end
    end

    describe '#expected' do
      it 'return the weighted mean value' do
        combined = described_class.add_distributions(distribution(:six), distribution(:ten))
        cases = [[distribution(:two), 1.5], [distribution(:four), 2.5], [distribution(:six), 3.5],
                 [distribution(:ten), 5.5], [combined, 9.0]]
        cases.each { |probability, expected| expect(probability.expected).to be_within(1e-9).of(expected) }
      end
    end

    describe '#given_ge' do
      it 'return a new distribution with probabilities calculated assuming value is >= target' do
        conditioned = distribution(:ten).given_ge(4)
        expect(distribution(:two).given_ge(2).to_h).to eql({ 2 => 1.0 })
        expect(conditioned.to_h).to be_valid_distribution
        expect(conditioned.p_eql(3)).to be 0.0
        expect(conditioned.p_eql(10)).to be_within(1.0e-9).of 0.1 / 0.7
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { distribution(:ten).given_ge([]) }.to raise_error TypeError
      end

      it 'clamp targets below the minimum and reject targets above the maximum' do
        expect(distribution(:ten).given_ge(0).to_h).to eql(distribution(:ten).to_h)
        expect { distribution(:ten).given_ge(11) }.to raise_error(RuntimeError, /divide by zero/)
      end
    end

    describe '#given_le' do
      it 'return a new distribution with probabilities calculated assuming value is <= target' do
        conditioned = distribution(:ten).given_le(4)
        expect(distribution(:two).given_le(2).to_h).to eql({ 1 => 0.5, 2 => 0.5 })
        expect(conditioned.to_h).to be_valid_distribution
        expect(conditioned.p_eql(3)).to be_within(1.0e-9).of 0.1 / 0.4
        expect(conditioned.p_eql(10)).to be 0.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { distribution(:ten).given_le({}) }.to raise_error TypeError
      end

      it 'clamp targets above the maximum and reject targets below the minimum' do
        expect(distribution(:ten).given_le(11).to_h).to eql(distribution(:ten).to_h)
        expect { distribution(:ten).given_le(0) }.to raise_error(RuntimeError, /divide by zero/)
      end
    end

    describe '#repeat_sum' do
      it 'output a valid distribution if params are valid' do
        expect(distribution(:uniform_four).repeat_sum(7).to_h).to be_valid_distribution
        expect(distribution(:weighted_four).repeat_sum(12).to_h).to be_valid_distribution
      end

      it 'raise an error if any param is unexpected type' do
        d6 = described_class.for_fair_die(6)
        expect { d6.repeat_sum({}) }.to raise_error TypeError
      end

      it 'raise an error if repetitions are not positive' do
        expect { distribution(:six).repeat_sum(0) }.to raise_error(RuntimeError, /n < 1/)
      end

      it 'raise an error if distribution would have more than a million results' do
        d1000 = described_class.for_fair_die(1000)
        expect { d1000.repeat_sum(11_000) }.to raise_error(RuntimeError, /Too many probability slots/)
      end

      it "calculate a '3d6' distribution accurately" do
        h = distribution(:six).repeat_sum(3).to_h
        expect(h).to be_valid_distribution
        numerators = [1, 3, 6, 10, 15, 21, 25, 27, 27, 25, 21, 15, 10, 6, 3, 1]
        expected = (3..18).zip(numerators.map { |numerator| numerator / 216.0 }).to_h
        expect_probability_values(h, expected, tolerance: 1e-9, total_tolerance: nil)
      end
    end

    describe '#repeat_n_sum_k' do
      it 'output a valid distribution if params are valid' do
        expect(distribution(:uniform_four).repeat_n_sum_k(3, 2).to_h).to be_valid_distribution
        expect(distribution(:weighted_four).repeat_n_sum_k(12, 4).to_h).to be_valid_distribution
      end

      it 'raise an error if any param is unexpected type' do
        d6 = described_class.for_fair_die(6)
        expect { d6.repeat_n_sum_k({}, 10) }.to raise_error TypeError
        expect { d6.repeat_n_sum_k(10, {}) }.to raise_error TypeError
      end

      it 'raise an error if repetitions or keepers are not positive' do
        expect { distribution(:six).repeat_n_sum_k(0, 1) }.to raise_error(RuntimeError, /n < 1/)
        expect { distribution(:six).repeat_n_sum_k(2, 0) }.to raise_error(RuntimeError, /k < 1/)
      end

      it 'sum every repetition when the keeper count is at least the repetition count' do
        expect(distribution(:six).repeat_n_sum_k(3, 3).to_h).to eql(distribution(:six).repeat_sum(3).to_h)
      end

      it 'raise an error if the kept distribution would have more than a million results' do
        d1000 = described_class.for_fair_die(1000)
        expect { d1000.repeat_n_sum_k(1003, 1002) }.to raise_error(RuntimeError, /Too many probability slots/)
      end

      it 'raise an error for an unknown keep mode' do
        expect { distribution(:six).repeat_n_sum_k(3, 2, :middle) }.to raise_error(ArgumentError, /Keep mode/)
      end

      it 'raise an error if n is greater than 170' do
        d6 = described_class.for_fair_die(6)
        expect { d6.repeat_n_sum_k(171, 10) }.to raise_error(RuntimeError, /Too many dice/)
      end

      it "calculate a '4d6 keep best 3' distribution accurately" do
        h = distribution(:six).repeat_n_sum_k(4, 3).to_h
        expect(h).to be_valid_distribution
        numerators = [1, 4, 10, 21, 38, 62, 91, 122, 148, 167, 172, 160, 131, 94, 54, 21]
        expected = (3..18).zip(numerators.map { |numerator| numerator / 1296.0 }).to_h
        expect_probability_values(h, expected, total_tolerance: nil)
      end

      it "calculate a '2d20 keep worst result' distribution accurately" do
        h = distribution(:twenty).repeat_n_sum_k(2, 1, :keep_worst).to_h
        expect(h).to be_valid_distribution
        expected = (1..20).to_h { |result| [result, (41 - (2 * result)) / 400.0] }
        expect_probability_values(h, expected, total_tolerance: nil)
      end

      it "calculate a '4d6 keep worst 3' distribution accurately at its bounds" do
        h = distribution(:six).repeat_n_sum_k(4, 3, :keep_worst).to_h
        expect(h).to be_valid_distribution
        expect(h[3]).to be_within(1e-10).of 21 / 1296.0
        expect(h[18]).to be_within(1e-10).of 1 / 1296.0
      end
    end
  end

  describe 'serialisation via Marshall' do
    it 'can load a saved GamesDice::Probabilities' do
      # RuboCop rationale: this repository-owned fixture verifies backwards-compatible Marshal deserialization.
      # rubocop:disable Security/MarshalLoad
      pd6 = File.open(fixture('probs_fair_die_6.dat')) { |file| Marshal.load(file) }
      # rubocop:enable Security/MarshalLoad
      expect(pd6.to_h).to be_valid_distribution
      expect(pd6.p_gt(4)).to be_within(1e-10).of 1.0 / 3
    end
  end
end
