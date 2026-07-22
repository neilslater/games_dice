# frozen_string_literal: true

require 'helpers'
require 'objspace'

describe GamesDice::Probabilities do
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
        pr2 = described_class.for_fair_die(2)
        expect(pr2).to be_a described_class
        expect(pr2.to_h).to eql({ 1 => 0.5, 2 => 0.5 })
        (1..20).each do |sides|
          pr = described_class.for_fair_die(sides)
          expect(pr).to be_a described_class
          h = pr.to_h
          expect(h).to be_valid_distribution
          expect(h.keys.count).to eql sides
          h.each_value { |v| expect(v).to be_within(1e-10).of 1.0 / sides }
        end
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
        d6 = described_class.for_fair_die(6)
        pr = described_class.add_distributions(d6, d6)
        h = pr.to_h
        expect(h).to be_valid_distribution
        expect(h[2]).to be_within(1e-9).of 1.0 / 36
        expect(h[3]).to be_within(1e-9).of 2.0 / 36
        expect(h[4]).to be_within(1e-9).of 3.0 / 36
        expect(h[5]).to be_within(1e-9).of 4.0 / 36
        expect(h[6]).to be_within(1e-9).of 5.0 / 36
        expect(h[7]).to be_within(1e-9).of 6.0 / 36
        expect(h[8]).to be_within(1e-9).of 5.0 / 36
        expect(h[9]).to be_within(1e-9).of 4.0 / 36
        expect(h[10]).to be_within(1e-9).of 3.0 / 36
        expect(h[11]).to be_within(1e-9).of 2.0 / 36
        expect(h[12]).to be_within(1e-9).of 1.0 / 36
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
        d6 = described_class.for_fair_die(6)
        d4 = described_class.for_fair_die(4)
        pr = described_class.add_distributions_mult(1, d6, -1, d4)
        h = pr.to_h
        expect(h).to be_valid_distribution
        expect(h[-3]).to be_within(1e-9).of 1.0 / 24
        expect(h[-2]).to be_within(1e-9).of 2.0 / 24
        expect(h[-1]).to be_within(1e-9).of 3.0 / 24
        expect(h[0]).to be_within(1e-9).of 4.0 / 24
        expect(h[1]).to be_within(1e-9).of 4.0 / 24
        expect(h[2]).to be_within(1e-9).of 4.0 / 24
        expect(h[3]).to be_within(1e-9).of 3.0 / 24
        expect(h[4]).to be_within(1e-9).of 2.0 / 24
        expect(h[5]).to be_within(1e-9).of 1.0 / 24
      end

      it 'add asymmetric distributions accurately' do
        da = described_class.new([0.7, 0.0, 0.3], 2)
        db = described_class.new([0.5, 0.3, 0.2], 2)
        pr = described_class.add_distributions_mult(1, da, 2, db)
        h = pr.to_h
        expect(h).to be_valid_distribution
        expect(h[6]).to be_within(1e-9).of 0.7 * 0.5
        expect(h[8]).to be_within(1e-9).of (0.7 * 0.3) + (0.3 * 0.5)
        expect(h[10]).to be_within(1e-9).of (0.7 * 0.2) + (0.3 * 0.3)
        expect(h[12]).to be_within(1e-9).of 0.3 * 0.2
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
    let(:pr2) { described_class.for_fair_die(2) }
    let(:pr4) { described_class.for_fair_die(4) }
    let(:pr6) { described_class.for_fair_die(6) }
    let(:pr10) { described_class.for_fair_die(10) }
    let(:pra) { described_class.new([0.4, 0.2, 0.4], -1) }

    describe '#clone' do
      it 'create an independent object with the same distribution' do
        copy = pra.clone
        expect(copy).not_to equal(pra)
        expect(copy.to_h).to eql(pra.to_h)
      end
    end

    describe 'native memory accounting' do
      it 'include allocated probability arrays' do
        empty = described_class.allocate
        expect(ObjectSpace.memsize_of(pr10)).to be > ObjectSpace.memsize_of(empty)
      end
    end

    describe '#each' do
      it 'iterate through all result/probability pairs' do
        yielded = []
        pr4.each { |r, p| yielded << [r, p] }
        expect(yielded).to eql [[1, 0.25], [2, 0.25], [3, 0.25], [4, 0.25]]
      end

      it 'skip zero probabilities' do
        pr_plus_minus = described_class.new([0.5, 0.0, 0.5], -1)
        yielded = []
        pr_plus_minus.each { |r, p| yielded << [r, p] }
        expect(yielded).to eql [[-1, 0.5], [1, 0.5]]
      end
    end

    describe '#p_eql' do
      it 'return probability of getting a number inside the range' do
        expect(pr2.p_eql(2)).to be_within(1.0e-9).of 0.5
        expect(pr4.p_eql(1)).to be_within(1.0e-9).of 0.25
        expect(pr6.p_eql(6)).to be_within(1.0e-9).of 1.0 / 6
        expect(pr10.p_eql(3)).to be_within(1.0e-9).of 0.1
        expect(pra.p_eql(-1)).to be_within(1.0e-9).of 0.4
      end

      it 'return 0.0 for values not covered by distribution' do
        expect(pr2.p_eql(3)).to be 0.0
        expect(pr4.p_eql(-1)).to be 0.0
        expect(pr6.p_eql(8)).to be 0.0
        expect(pr10.p_eql(11)).to be 0.0
        expect(pra.p_eql(2)).to be 0.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { pr2.p_eql([]) }.to raise_error TypeError
      end
    end

    describe '#p_gt' do
      it 'return probability of getting a number greater than target' do
        expect(pr2.p_gt(1)).to be_within(1.0e-9).of 0.5
        expect(pr4.p_gt(3)).to be_within(1.0e-9).of 0.25
        expect(pr6.p_gt(2)).to be_within(1.0e-9).of 4.0 / 6
        expect(pr10.p_gt(6)).to be_within(1.0e-9).of 0.4

        # Trying more than one, due to possibilities of caching error (in pure Ruby implementation)
        expect(pra.p_gt(-2)).to be_within(1.0e-9).of 1.0
        expect(pra.p_gt(-1)).to be_within(1.0e-9).of 0.6
        expect(pra.p_gt(0)).to be_within(1.0e-9).of 0.4
        expect(pra.p_gt(1)).to be_within(1.0e-9).of 0.0
      end

      it 'return 0.0 when the target number is equal or higher than maximum possible' do
        expect(pr2.p_gt(2)).to be 0.0
        expect(pr4.p_gt(5)).to be 0.0
        expect(pr6.p_gt(6)).to be 0.0
        expect(pr10.p_gt(20)).to be 0.0
        expect(pra.p_gt(3)).to be 0.0
      end

      it 'return 1.0 when the target number is lower than minimum' do
        expect(pr2.p_gt(0)).to be 1.0
        expect(pr4.p_gt(-5)).to be 1.0
        expect(pr6.p_gt(0)).to be 1.0
        expect(pr10.p_gt(-200)).to be 1.0
        expect(pra.p_gt(-2)).to be 1.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { pr2.p_gt({}) }.to raise_error TypeError
      end
    end

    describe '#p_ge' do
      it 'return probability of getting a number greater than or equal to target' do
        expect(pr2.p_ge(2)).to be_within(1.0e-9).of 0.5
        expect(pr4.p_ge(3)).to be_within(1.0e-9).of 0.5
        expect(pr6.p_ge(2)).to be_within(1.0e-9).of 5.0 / 6
        expect(pr10.p_ge(6)).to be_within(1.0e-9).of 0.5
      end

      it 'return 0.0 when the target number is higher than maximum possible' do
        expect(pr2.p_ge(6)).to be 0.0
        expect(pr4.p_ge(5)).to be 0.0
        expect(pr6.p_ge(7)).to be 0.0
        expect(pr10.p_ge(20)).to be 0.0
      end

      it 'return 1.0 when the target number is lower than or equal to minimum possible' do
        expect(pr2.p_ge(1)).to be 1.0
        expect(pr4.p_ge(-5)).to be 1.0
        expect(pr6.p_ge(1)).to be 1.0
        expect(pr10.p_ge(-200)).to be 1.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { pr4.p_ge({}) }.to raise_error TypeError
      end
    end

    describe '#p_le' do
      it 'return probability of getting a number less than or equal to target' do
        expect(pr2.p_le(1)).to be_within(1.0e-9).of 0.5
        expect(pr4.p_le(2)).to be_within(1.0e-9).of 0.5
        expect(pr6.p_le(2)).to be_within(1.0e-9).of 2.0 / 6
        expect(pr10.p_le(6)).to be_within(1.0e-9).of 0.6
      end

      it 'return 1.0 when the target number is higher than or equal to maximum possible' do
        expect(pr2.p_le(6)).to be 1.0
        expect(pr4.p_le(4)).to be 1.0
        expect(pr6.p_le(7)).to be 1.0
        expect(pr10.p_le(10)).to be 1.0
      end

      it 'return 0.0 when the target number is lower than minimum possible' do
        expect(pr2.p_le(0)).to be 0.0
        expect(pr4.p_le(-5)).to be 0.0
        expect(pr6.p_le(0)).to be 0.0
        expect(pr10.p_le(-200)).to be 0.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { pr4.p_le([]) }.to raise_error TypeError
      end
    end

    describe '#p_lt' do
      it 'return probability of getting a number less than target' do
        expect(pr2.p_lt(2)).to be_within(1.0e-9).of 0.5
        expect(pr4.p_lt(3)).to be_within(1.0e-9).of 0.5
        expect(pr6.p_lt(2)).to be_within(1.0e-9).of 1 / 6.0
        expect(pr10.p_lt(6)).to be_within(1.0e-9).of 0.5
      end

      it 'return 1.0 when the target number is higher than maximum possible' do
        expect(pr2.p_lt(6)).to be 1.0
        expect(pr4.p_lt(5)).to be 1.0
        expect(pr6.p_lt(7)).to be 1.0
        expect(pr10.p_lt(20)).to be 1.0
      end

      it 'return 0.0 when the target number is lower than or equal to minimum possible' do
        expect(pr2.p_lt(1)).to be 0.0
        expect(pr4.p_lt(-5)).to be 0.0
        expect(pr6.p_lt(1)).to be 0.0
        expect(pr10.p_lt(-200)).to be 0.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { pr6.p_lt({}) }.to raise_error TypeError
      end
    end

    describe '#to_h' do
      # This is used loads in other tests
      it 'represent a valid distribution with each integer result associated with its probability' do
        expect(pr2.to_h).to be_valid_distribution
        expect(pr4.to_h).to be_valid_distribution
        expect(pr6.to_h).to be_valid_distribution
        expect(pr10.to_h).to be_valid_distribution
      end
    end

    describe '#min' do
      it 'return lowest possible result allowed by distribution' do
        expect(pr2.min).to be 1
        expect(pr4.min).to be 1
        expect(pr6.min).to be 1
        expect(pr10.min).to be 1
        expect(described_class.add_distributions(pr6, pr10).min).to be 2
      end
    end

    describe '#max' do
      it 'return highest possible result allowed by distribution' do
        expect(pr2.max).to be 2
        expect(pr4.max).to be 4
        expect(pr6.max).to be 6
        expect(pr10.max).to be 10
        expect(described_class.add_distributions(pr6, pr10).max).to be 16
      end
    end

    describe '#expected' do
      it 'return the weighted mean value' do
        expect(pr2.expected).to be_within(1.0e-9).of 1.5
        expect(pr4.expected).to be_within(1.0e-9).of 2.5
        expect(pr6.expected).to be_within(1.0e-9).of 3.5
        expect(pr10.expected).to be_within(1.0e-9).of 5.5
        expect(described_class.add_distributions(pr6, pr10).expected).to be_within(1.0e-9).of 9.0
      end
    end

    describe '#given_ge' do
      it 'return a new distribution with probabilities calculated assuming value is >= target' do
        pd = pr2.given_ge(2)
        expect(pd.to_h).to eql({ 2 => 1.0 })
        pd = pr10.given_ge(4)
        expect(pd.to_h).to be_valid_distribution
        expect(pd.p_eql(3)).to be 0.0
        expect(pd.p_eql(10)).to be_within(1.0e-9).of 0.1 / 0.7
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { pr10.given_ge([]) }.to raise_error TypeError
      end

      it 'clamp targets below the minimum and reject targets above the maximum' do
        expect(pr10.given_ge(0).to_h).to eql(pr10.to_h)
        expect { pr10.given_ge(11) }.to raise_error(RuntimeError, /divide by zero/)
      end
    end

    describe '#given_le' do
      it 'return a new distribution with probabilities calculated assuming value is <= target' do
        pd = pr2.given_le(2)
        expect(pd.to_h).to eql({ 1 => 0.5, 2 => 0.5 })
        pd = pr10.given_le(4)
        expect(pd.to_h).to be_valid_distribution
        expect(pd.p_eql(3)).to be_within(1.0e-9).of 0.1 / 0.4
        expect(pd.p_eql(10)).to be 0.0
      end

      it 'raise a TypeError if asked for probability of non-Integer' do
        expect { pr10.given_le({}) }.to raise_error TypeError
      end

      it 'clamp targets above the maximum and reject targets below the minimum' do
        expect(pr10.given_le(11).to_h).to eql(pr10.to_h)
        expect { pr10.given_le(0) }.to raise_error(RuntimeError, /divide by zero/)
      end
    end

    describe '#repeat_sum' do
      it 'output a valid distribution if params are valid' do
        d4a = described_class.new([1.0 / 4, 1.0 / 4, 1.0 / 4, 1.0 / 4], 1)
        d4b = described_class.new([1.0 / 10, 2.0 / 10, 3.0 / 10, 4.0 / 10], 1)
        pr = d4a.repeat_sum(7)
        expect(pr.to_h).to be_valid_distribution
        pr = d4b.repeat_sum(12)
        expect(pr.to_h).to be_valid_distribution
      end

      it 'raise an error if any param is unexpected type' do
        d6 = described_class.for_fair_die(6)
        expect { d6.repeat_sum({}) }.to raise_error TypeError
      end

      it 'raise an error if repetitions are not positive' do
        expect { pr6.repeat_sum(0) }.to raise_error(RuntimeError, /n < 1/)
      end

      it 'raise an error if distribution would have more than a million results' do
        d1000 = described_class.for_fair_die(1000)
        expect { d1000.repeat_sum(11_000) }.to raise_error(RuntimeError, /Too many probability slots/)
      end

      it "calculate a '3d6' distribution accurately" do
        d6 = described_class.for_fair_die(6)
        pr = d6.repeat_sum(3)
        h = pr.to_h
        expect(h).to be_valid_distribution
        expect(h[3]).to be_within(1e-9).of 1.0 / 216
        expect(h[4]).to be_within(1e-9).of 3.0 / 216
        expect(h[5]).to be_within(1e-9).of 6.0 / 216
        expect(h[6]).to be_within(1e-9).of 10.0 / 216
        expect(h[7]).to be_within(1e-9).of 15.0 / 216
        expect(h[8]).to be_within(1e-9).of 21.0 / 216
        expect(h[9]).to be_within(1e-9).of 25.0 / 216
        expect(h[10]).to be_within(1e-9).of 27.0 / 216
        expect(h[11]).to be_within(1e-9).of 27.0 / 216
        expect(h[12]).to be_within(1e-9).of 25.0 / 216
        expect(h[13]).to be_within(1e-9).of 21.0 / 216
        expect(h[14]).to be_within(1e-9).of 15.0 / 216
        expect(h[15]).to be_within(1e-9).of 10.0 / 216
        expect(h[16]).to be_within(1e-9).of 6.0 / 216
        expect(h[17]).to be_within(1e-9).of 3.0 / 216
        expect(h[18]).to be_within(1e-9).of 1.0 / 216
      end
    end

    describe '#repeat_n_sum_k' do
      it 'output a valid distribution if params are valid' do
        d4a = described_class.new([1.0 / 4, 1.0 / 4, 1.0 / 4, 1.0 / 4], 1)
        d4b = described_class.new([1.0 / 10, 2.0 / 10, 3.0 / 10, 4.0 / 10], 1)
        pr = d4a.repeat_n_sum_k(3, 2)
        expect(pr.to_h).to be_valid_distribution
        pr = d4b.repeat_n_sum_k(12, 4)
        expect(pr.to_h).to be_valid_distribution
      end

      it 'raise an error if any param is unexpected type' do
        d6 = described_class.for_fair_die(6)
        expect { d6.repeat_n_sum_k({}, 10) }.to raise_error TypeError
        expect { d6.repeat_n_sum_k(10, {}) }.to raise_error TypeError
      end

      it 'raise an error if repetitions or keepers are not positive' do
        expect { pr6.repeat_n_sum_k(0, 1) }.to raise_error(RuntimeError, /n < 1/)
        expect { pr6.repeat_n_sum_k(2, 0) }.to raise_error(RuntimeError, /k < 1/)
      end

      it 'sum every repetition when the keeper count is at least the repetition count' do
        expect(pr6.repeat_n_sum_k(3, 3).to_h).to eql(pr6.repeat_sum(3).to_h)
      end

      it 'raise an error if the kept distribution would have more than a million results' do
        d1000 = described_class.for_fair_die(1000)
        expect { d1000.repeat_n_sum_k(1003, 1002) }.to raise_error(RuntimeError, /Too many probability slots/)
      end

      it 'raise an error for an unknown keep mode' do
        expect { pr6.repeat_n_sum_k(3, 2, :middle) }.to raise_error(ArgumentError, /Keep mode/)
      end

      it 'raise an error if n is greater than 170' do
        d6 = described_class.for_fair_die(6)
        expect { d6.repeat_n_sum_k(171, 10) }.to raise_error(RuntimeError, /Too many dice/)
      end

      it "calculate a '4d6 keep best 3' distribution accurately" do
        d6 = described_class.for_fair_die(6)
        pr = d6.repeat_n_sum_k(4, 3)
        h = pr.to_h
        expect(h).to be_valid_distribution
        expect(h[3]).to be_within(1e-10).of 1 / 1296.0
        expect(h[4]).to be_within(1e-10).of 4 / 1296.0
        expect(h[5]).to be_within(1e-10).of 10 / 1296.0
        expect(h[6]).to be_within(1e-10).of 21 / 1296.0
        expect(h[7]).to be_within(1e-10).of 38 / 1296.0
        expect(h[8]).to be_within(1e-10).of 62 / 1296.0
        expect(h[9]).to be_within(1e-10).of 91 / 1296.0
        expect(h[10]).to be_within(1e-10).of 122 / 1296.0
        expect(h[11]).to be_within(1e-10).of 148 / 1296.0
        expect(h[12]).to be_within(1e-10).of 167 / 1296.0
        expect(h[13]).to be_within(1e-10).of 172 / 1296.0
        expect(h[14]).to be_within(1e-10).of 160 / 1296.0
        expect(h[15]).to be_within(1e-10).of 131 / 1296.0
        expect(h[16]).to be_within(1e-10).of 94 / 1296.0
        expect(h[17]).to be_within(1e-10).of 54 / 1296.0
        expect(h[18]).to be_within(1e-10).of 21 / 1296.0
      end

      it "calculate a '2d20 keep worst result' distribution accurately" do
        d20 = described_class.for_fair_die(20)
        pr = d20.repeat_n_sum_k(2, 1, :keep_worst)
        h = pr.to_h
        expect(h).to be_valid_distribution
        expect(h[1]).to be_within(1e-10).of 39 / 400.0
        expect(h[2]).to be_within(1e-10).of 37 / 400.0
        expect(h[3]).to be_within(1e-10).of 35 / 400.0
        expect(h[4]).to be_within(1e-10).of 33 / 400.0
        expect(h[5]).to be_within(1e-10).of 31 / 400.0
        expect(h[6]).to be_within(1e-10).of 29 / 400.0
        expect(h[7]).to be_within(1e-10).of 27 / 400.0
        expect(h[8]).to be_within(1e-10).of 25 / 400.0
        expect(h[9]).to be_within(1e-10).of 23 / 400.0
        expect(h[10]).to be_within(1e-10).of 21 / 400.0
        expect(h[11]).to be_within(1e-10).of 19 / 400.0
        expect(h[12]).to be_within(1e-10).of 17 / 400.0
        expect(h[13]).to be_within(1e-10).of 15 / 400.0
        expect(h[14]).to be_within(1e-10).of 13 / 400.0
        expect(h[15]).to be_within(1e-10).of 11 / 400.0
        expect(h[16]).to be_within(1e-10).of 9 / 400.0
        expect(h[17]).to be_within(1e-10).of 7 / 400.0
        expect(h[18]).to be_within(1e-10).of 5 / 400.0
        expect(h[19]).to be_within(1e-10).of 3 / 400.0
        expect(h[20]).to be_within(1e-10).of 1 / 400.0
      end

      it "calculate a '4d6 keep worst 3' distribution accurately at its bounds" do
        h = pr6.repeat_n_sum_k(4, 3, :keep_worst).to_h
        expect(h).to be_valid_distribution
        expect(h[3]).to be_within(1e-10).of 21 / 1296.0
        expect(h[18]).to be_within(1e-10).of 1 / 1296.0
      end
    end
  end

  describe 'serialisation via Marshall' do
    it 'can load a saved GamesDice::Probabilities' do
      # rubocop:disable Security/MarshalLoad
      # This is a test of using Marshal on a fixed test file
      pd6 = File.open(fixture('probs_fair_die_6.dat')) { |file| Marshal.load(file) }
      # rubocop:enable Security/MarshalLoad
      expect(pd6.to_h).to be_valid_distribution
      expect(pd6.p_gt(4)).to be_within(1e-10).of 1.0 / 3
    end
  end
end
