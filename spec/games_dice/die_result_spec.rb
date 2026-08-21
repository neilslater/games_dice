# frozen_string_literal: true

require 'helpers'

describe GamesDice::DieResult, :aggregate_failures do
  let(:seven_result) { described_class.new(7) }
  let(:twelve_result) do
    result = described_class.new(6)
    result.add_roll(6, :reroll_add)
    result
  end

  describe '.new' do
    it "work without parameters to represent 'no results yet'" do
      die_result = described_class.new
      expect(die_result.value).to be_nil
      expect(die_result.rolls).to eql []
      expect(die_result.roll_reasons).to eql []
    end

    it 'work with a single Integer param to represent an initial result' do
      die_result = described_class.new(8)
      expect(die_result.value).to be 8
      expect(die_result.rolls).to eql [8]
      expect(die_result.roll_reasons).to eql [:basic]
    end

    it 'not accept a param that cannot be coerced to Integer' do
      expect { described_class.new([]) }.to raise_error(TypeError)
      expect { described_class.new('N') }.to raise_error(ArgumentError)
    end

    it 'not accept unknown reasons for making a roll' do
      expect { described_class.new(8, 'wooo') }.to raise_error(ArgumentError)
      expect { described_class.new(8, :frabulous) }.to raise_error(ArgumentError)
    end
  end

  describe '#add_roll' do
    context "when starting from 'no results yet'" do
      let(:die_result) { described_class.new }

      it 'create an initial result' do
        die_result.add_roll(5)
        expect(die_result.value).to be 5
        expect(die_result.rolls).to eql [5]
        expect(die_result.roll_reasons).to eql [:basic]
      end

      it 'accept non-basic reasons for the first roll' do
        die_result.add_roll(4, :reroll_subtract)
        expect(die_result.value).to be(-4)
        expect(die_result.rolls).to eql [4]
        expect(die_result.roll_reasons).to eql [:reroll_subtract]
      end

      it 'not accept a first param that cannot be coerced to Integer' do
        expect { die_result.add_roll([]) }.to raise_error(TypeError)
        expect { die_result.add_roll('N') }.to raise_error(ArgumentError)
      end

      it 'not accept an unsupported second param' do
        expect { die_result.add_roll(5, []) }.to raise_error(ArgumentError)
        expect { die_result.add_roll(15, :bam) }.to raise_error(ArgumentError)
      end
    end

    context 'when starting with an initial result' do
      let(:die_result) { described_class.new(7) }

      it 'not accept a first param that cannot be coerced to Integer' do
        expect { die_result.add_roll([]) }.to raise_error(TypeError)
        expect { die_result.add_roll('N') }.to raise_error(ArgumentError)
      end

      it 'not accept an unsupported second param' do
        expect { die_result.add_roll(5, []) }.to raise_error(ArgumentError)
        expect { die_result.add_roll(15, :bam) }.to raise_error(ArgumentError)
      end

      it 'replace an initial result, as if the die were re-rolled' do
        die_result.add_roll(5)
        expect(die_result.value).to be 5
        expect(die_result.rolls).to eql [7, 5]
        expect(die_result.roll_reasons).to eql %i[basic basic]
      end

      it 'add to value when exploding up' do
        die_result.add_roll(6, :reroll_add)
        expect(die_result.value).to be 13
        expect(die_result.rolls).to eql [7, 6]
        expect(die_result.roll_reasons).to eql %i[basic reroll_add]
      end

      it 'subtract from value when exploding down' do
        die_result.add_roll(4, :reroll_subtract)
        expect(die_result.value).to be 3
        expect(die_result.rolls).to eql [7, 4]
        expect(die_result.roll_reasons).to eql %i[basic reroll_subtract]
      end

      it 'optionally replace roll unconditionally' do
        steps = [[[2, :reroll_replace], 2, [7, 2], %i[basic reroll_replace]],
                 [[5, :reroll_replace], 5, [7, 2, 5], %i[basic reroll_replace reroll_replace]]]
        steps.each do |arguments, value, rolls, reasons|
          die_result.add_roll(*arguments)
          expect_die_result_state(die_result, value: value, rolls: rolls, reasons: reasons)
        end
      end

      it 'optionally use best roll' do
        steps = [[[2, :reroll_use_best], 7, [7, 2], %i[basic reroll_use_best]],
                 [[9, :reroll_use_best], 9, [7, 2, 9], %i[basic reroll_use_best reroll_use_best]]]
        steps.each do |arguments, value, rolls, reasons|
          die_result.add_roll(*arguments)
          expect_die_result_state(die_result, value: value, rolls: rolls, reasons: reasons)
        end
      end

      it 'optionally use worst roll' do
        steps = [[[4, :reroll_use_worst], 4, [7, 4], %i[basic reroll_use_worst]],
                 [[5, :reroll_use_worst], 4, [7, 4, 5], %i[basic reroll_use_worst reroll_use_worst]]]
        steps.each do |arguments, value, rolls, reasons|
          die_result.add_roll(*arguments)
          expect_die_result_state(die_result, value: value, rolls: rolls, reasons: reasons)
        end
      end

      it 'correctly handle valid reasons for extra rolls in combination' do
        steps = [[[[10, :reroll_add], [3, :reroll_subtract]], 14, [7, 10, 3], %i[basic reroll_add reroll_subtract]],
                 [[[12, :reroll_replace]], 12, [7, 10, 3, 12], %i[basic reroll_add reroll_subtract reroll_replace]],
                 [[[9, :reroll_use_best]], 12, [7, 10, 3, 12, 9],
                  %i[basic reroll_add reroll_subtract reroll_replace reroll_use_best]],
                 [[[15, :reroll_add]], 27, [7, 10, 3, 12, 9, 15],
                  %i[basic reroll_add reroll_subtract reroll_replace reroll_use_best reroll_add]]]
        steps.each do |rolls_to_add, value, rolls, reasons|
          rolls_to_add.each { |arguments| die_result.add_roll(*arguments) }
          expect_die_result_state(die_result, value: value, rolls: rolls, reasons: reasons)
        end
      end
    end
  end

  describe '#explain_value' do
    let(:die_result) { described_class.new }

    it "be empty string for 'no results yet'" do
      expect(die_result.explain_value).to eql ''
    end

    it 'be a simple stringified number when there is one die roll' do
      die_result.add_roll(3)
      expect(die_result.explain_value).to eql '3'
    end

    it 'describe all single rolls made and how they combine' do
      steps = [[[6], '6'], [[5, :reroll_add], '[6+5] 11'], [[2, :reroll_replace], '[6+5|2] 2'],
               [[7, :reroll_subtract], '[6+5|2-7] -5'], [[4, :reroll_use_worst], '[6+5|2-7\\4] -5'],
               [[3, :reroll_use_best], '[6+5|2-7\\4/3] 3']]
      steps.each do |arguments, expected|
        die_result.add_roll(*arguments)
        expect(die_result.explain_value).to eq(expected)
      end
    end
  end

  it 'combine via +,- and * intuitively based on #value' do
    cases = [[seven_result + 3, 10], [4 + seven_result, 11], [seven_result - 2, 5], [9 - seven_result, 2],
             [seven_result + 7.7, 14.7], [4.1 + seven_result, 11.1], [seven_result * 2, 14], [1 * seven_result, 7],
             [seven_result + twelve_result, 19], [twelve_result - seven_result, 5]]
    cases.each { |actual, expected| expect(actual).to eq(expected) }
  end

  it 'support comparison with >,<,>=,<= as if it were an integer, based on #value' do
    cases = [[seven_result > 3, true], [seven_result < 14, true], [seven_result >= 7, true],
             [seven_result <= 9.5, true], [seven_result < 3, false], [seven_result > 14, false],
             [seven_result <= 8, true], [seven_result >= 14, false], [seven_result > twelve_result, false],
             [twelve_result > seven_result, true], [seven_result >= twelve_result, false],
             [twelve_result >= seven_result, true], [seven_result < twelve_result, true],
             [twelve_result < seven_result, false], [seven_result <= twelve_result, true],
             [twelve_result <= seven_result, false]]
    cases.each { |actual, expected| expect(actual).to be(expected) }
  end

  it 'sort, based on #value' do
    die_results = [
      described_class.new(7), described_class.new(5), described_class.new(8), described_class.new(3)
    ]

    die_results.sort!

    expect(die_results.map(&:value)).to eq([3, 5, 7, 8])
  end
end
