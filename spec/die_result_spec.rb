# frozen_string_literal: true

require 'helpers'

describe GamesDice::DieResult do
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

      context 'when adding another basic roll' do
        it 'replace an initial result, as if the die were re-rolled' do
          die_result.add_roll(5)
          expect(die_result.value).to be 5
          expect(die_result.rolls).to eql [7, 5]
          expect(die_result.roll_reasons).to eql %i[basic basic]
        end
      end

      context 'with exploding dice' do
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
      end

      context 'with re-roll dice' do
        it 'optionally replace roll unconditionally' do
          die_result.add_roll(2, :reroll_replace)
          expect(die_result.value).to be 2
          expect(die_result.rolls).to eql [7, 2]
          expect(die_result.roll_reasons).to eql %i[basic reroll_replace]

          die_result.add_roll(5, :reroll_replace)
          expect(die_result.value).to be 5
          expect(die_result.rolls).to eql [7, 2, 5]
          expect(die_result.roll_reasons).to eql %i[basic reroll_replace reroll_replace]
        end

        it 'optionally use best roll' do
          die_result.add_roll(2, :reroll_use_best)
          expect(die_result.value).to be 7
          expect(die_result.rolls).to eql [7, 2]
          expect(die_result.roll_reasons).to eql %i[basic reroll_use_best]

          die_result.add_roll(9, :reroll_use_best)
          expect(die_result.value).to be 9
          expect(die_result.rolls).to eql [7, 2, 9]
          expect(die_result.roll_reasons).to eql %i[basic reroll_use_best reroll_use_best]
        end

        it 'optionally use worst roll' do
          die_result.add_roll(4, :reroll_use_worst)
          expect(die_result.value).to be 4
          expect(die_result.rolls).to eql [7, 4]
          expect(die_result.roll_reasons).to eql %i[basic reroll_use_worst]

          die_result.add_roll(5, :reroll_use_worst)
          expect(die_result.value).to be 4
          expect(die_result.rolls).to eql [7, 4, 5]
          expect(die_result.roll_reasons).to eql %i[basic reroll_use_worst reroll_use_worst]
        end
      end

      context 'with combinations of reroll reasons' do
        it 'correctly handle valid reasons for extra rolls in combination' do
          die_result.add_roll(10, :reroll_add)
          die_result.add_roll(3, :reroll_subtract)
          expect(die_result.value).to be 14
          expect(die_result.rolls).to eql [7, 10, 3]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add reroll_subtract]

          die_result.add_roll(12, :reroll_replace)
          expect(die_result.value).to be 12
          expect(die_result.rolls).to eql [7, 10, 3, 12]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add reroll_subtract reroll_replace]

          die_result.add_roll(9, :reroll_use_best)
          expect(die_result.value).to be 12
          expect(die_result.rolls).to eql [7, 10, 3, 12, 9]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add reroll_subtract reroll_replace
                                                    reroll_use_best]

          die_result.add_roll(15, :reroll_add)
          expect(die_result.value).to be 27
          expect(die_result.rolls).to eql [7, 10, 3, 12, 9, 15]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add reroll_subtract reroll_replace
                                                    reroll_use_best reroll_add]
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
      die_result.add_roll(6)
      expect(die_result.explain_value).to eql '6'

      die_result.add_roll(5, :reroll_add)
      expect(die_result.explain_value).to eql '[6+5] 11'

      die_result.add_roll(2, :reroll_replace)
      expect(die_result.explain_value).to eql '[6+5|2] 2'

      die_result.add_roll(7, :reroll_subtract)
      expect(die_result.explain_value).to eql '[6+5|2-7] -5'

      die_result.add_roll(4, :reroll_use_worst)
      expect(die_result.explain_value).to eql '[6+5|2-7\\4] -5'

      die_result.add_roll(3, :reroll_use_best)
      expect(die_result.explain_value).to eql '[6+5|2-7\\4/3] 3'
    end
  end

  it 'combine via +,- and * intuitively based on #value' do
    die_result = described_class.new(7)
    expect(die_result + 3).to be 10
    expect(4 + die_result).to be 11
    expect(die_result - 2).to be 5
    expect(9 - die_result).to be 2

    expect(die_result + 7.7).to be 14.7
    expect(4.1 + die_result).to be 11.1

    expect(die_result * 2).to be 14
    expect(1 * die_result).to be 7

    other_die_result = described_class.new(6)
    other_die_result.add_roll(6, :reroll_add)
    expect(die_result + other_die_result).to be 19
    expect(other_die_result - die_result).to be 5
  end

  it 'support comparison with >,<,>=,<= as if it were an integer, based on #value' do
    die_result = described_class.new(7)

    expect(die_result > 3).to be true
    expect(die_result < 14).to be true
    expect(die_result >= 7).to be true
    expect(die_result <= 9.5).to be true
    expect(die_result < 3).to be false
    expect(die_result > 14).to be false
    expect(die_result <= 8).to be true
    expect(die_result >= 14).to be false

    other_die_result = described_class.new(6)
    other_die_result.add_roll(6, :reroll_add)
    expect(die_result > other_die_result).to be false
    expect(other_die_result > die_result).to be true
    expect(die_result >= other_die_result).to be false
    expect(other_die_result >= die_result).to be true
    expect(die_result < other_die_result).to be true
    expect(other_die_result < die_result).to be false
    expect(die_result <= other_die_result).to be true
    expect(other_die_result <= die_result).to be false
  end

  it 'sort, based on #value' do
    die_results = [
      described_class.new(7), described_class.new(5), described_class.new(8), described_class.new(3)
    ]

    die_results.sort!

    expect(die_results[0].value).to be 3
    expect(die_results[1].value).to be 5
    expect(die_results[2].value).to be 7
    expect(die_results[3].value).to be 8
  end
end
