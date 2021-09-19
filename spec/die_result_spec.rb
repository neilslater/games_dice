# frozen_string_literal: true

require 'helpers'

describe GamesDice::DieResult do
  describe '.new' do
    it "should work without parameters to represent 'no results yet'" do
      die_result = GamesDice::DieResult.new
      expect(die_result.value).to eql nil
      expect(die_result.rolls).to eql []
      expect(die_result.roll_reasons).to eql []
    end

    it 'should work with a single Integer param to represent an initial result' do
      die_result = GamesDice::DieResult.new(8)
      expect(die_result.value).to eql 8
      expect(die_result.rolls).to eql [8]
      expect(die_result.roll_reasons).to eql [:basic]
    end

    it 'should not accept a param that cannot be coerced to Integer' do
      expect(-> { GamesDice::DieResult.new([]) }).to raise_error(TypeError)
      expect(-> { GamesDice::DieResult.new('N') }).to raise_error(ArgumentError)
    end

    it 'should not accept unknown reasons for making a roll' do
      expect(-> { GamesDice::DieResult.new(8, 'wooo') }).to raise_error(ArgumentError)
      expect(-> { GamesDice::DieResult.new(8, :frabulous) }).to raise_error(ArgumentError)
    end
  end

  describe '#add_roll' do
    context "starting from 'no results yet'" do
      let(:die_result) { GamesDice::DieResult.new }

      it 'should create an initial result' do
        die_result.add_roll(5)
        expect(die_result.value).to eql 5
        expect(die_result.rolls).to eql [5]
        expect(die_result.roll_reasons).to eql [:basic]
      end

      it 'should accept non-basic reasons for the first roll' do
        die_result.add_roll(4, :reroll_subtract)
        expect(die_result.value).to eql(-4)
        expect(die_result.rolls).to eql [4]
        expect(die_result.roll_reasons).to eql [:reroll_subtract]
      end

      it 'should not accept a first param that cannot be coerced to Integer' do
        expect(-> { die_result.add_roll([]) }).to raise_error(TypeError)
        expect(-> { die_result.add_roll('N') }).to raise_error(ArgumentError)
      end

      it 'should not accept an unsupported second param' do
        expect(-> { die_result.add_roll(5, []) }).to raise_error(ArgumentError)
        expect(-> { die_result.add_roll(15, :bam) }).to raise_error(ArgumentError)
      end
    end

    context 'starting with an initial result' do
      let(:die_result) { GamesDice::DieResult.new(7) }

      it 'should not accept a first param that cannot be coerced to Integer' do
        expect(-> { die_result.add_roll([]) }).to raise_error(TypeError)
        expect(-> { die_result.add_roll('N') }).to raise_error(ArgumentError)
      end

      it 'should not accept an unsupported second param' do
        expect(-> { die_result.add_roll(5, []) }).to raise_error(ArgumentError)
        expect(-> { die_result.add_roll(15, :bam) }).to raise_error(ArgumentError)
      end

      context 'add another basic roll' do
        it 'should replace an initial result, as if the die were re-rolled' do
          die_result.add_roll(5)
          expect(die_result.value).to eql 5
          expect(die_result.rolls).to eql [7, 5]
          expect(die_result.roll_reasons).to eql %i[basic basic]
        end
      end

      context 'exploding dice' do
        it 'should add to value when exploding up' do
          die_result.add_roll(6, :reroll_add)
          expect(die_result.value).to eql 13
          expect(die_result.rolls).to eql [7, 6]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add]
        end

        it 'should subtract from value when exploding down' do
          die_result.add_roll(4, :reroll_subtract)
          expect(die_result.value).to eql 3
          expect(die_result.rolls).to eql [7, 4]
          expect(die_result.roll_reasons).to eql %i[basic reroll_subtract]
        end
      end

      context 're-roll dice' do
        it 'should optionally replace roll unconditionally' do
          die_result.add_roll(2, :reroll_replace)
          expect(die_result.value).to eql 2
          expect(die_result.rolls).to eql [7, 2]
          expect(die_result.roll_reasons).to eql %i[basic reroll_replace]

          die_result.add_roll(5, :reroll_replace)
          expect(die_result.value).to eql 5
          expect(die_result.rolls).to eql [7, 2, 5]
          expect(die_result.roll_reasons).to eql %i[basic reroll_replace reroll_replace]
        end

        it 'should optionally use best roll' do
          die_result.add_roll(2, :reroll_use_best)
          expect(die_result.value).to eql 7
          expect(die_result.rolls).to eql [7, 2]
          expect(die_result.roll_reasons).to eql %i[basic reroll_use_best]

          die_result.add_roll(9, :reroll_use_best)
          expect(die_result.value).to eql 9
          expect(die_result.rolls).to eql [7, 2, 9]
          expect(die_result.roll_reasons).to eql %i[basic reroll_use_best reroll_use_best]
        end

        it 'should optionally use worst roll' do
          die_result.add_roll(4, :reroll_use_worst)
          expect(die_result.value).to eql 4
          expect(die_result.rolls).to eql [7, 4]
          expect(die_result.roll_reasons).to eql %i[basic reroll_use_worst]

          die_result.add_roll(5, :reroll_use_worst)
          expect(die_result.value).to eql 4
          expect(die_result.rolls).to eql [7, 4, 5]
          expect(die_result.roll_reasons).to eql %i[basic reroll_use_worst reroll_use_worst]
        end
      end

      context 'combinations of reroll reasons' do
        it 'should correctly handle valid reasons for extra rolls in combination' do
          die_result.add_roll(10, :reroll_add)
          die_result.add_roll(3, :reroll_subtract)
          expect(die_result.value).to eql 14
          expect(die_result.rolls).to eql [7, 10, 3]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add reroll_subtract]

          die_result.add_roll(12, :reroll_replace)
          expect(die_result.value).to eql 12
          expect(die_result.rolls).to eql [7, 10, 3, 12]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add reroll_subtract reroll_replace]

          die_result.add_roll(9, :reroll_use_best)
          expect(die_result.value).to eql 12
          expect(die_result.rolls).to eql [7, 10, 3, 12, 9]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add reroll_subtract reroll_replace
                                                    reroll_use_best]

          die_result.add_roll(15, :reroll_add)
          expect(die_result.value).to eql 27
          expect(die_result.rolls).to eql [7, 10, 3, 12, 9, 15]
          expect(die_result.roll_reasons).to eql %i[basic reroll_add reroll_subtract reroll_replace
                                                    reroll_use_best reroll_add]
        end
      end
    end
  end

  describe '#explain_value' do
    let(:die_result) { GamesDice::DieResult.new }

    it "should be empty string for 'no results yet'" do
      expect(die_result.explain_value).to eql ''
    end

    it 'should be a simple stringified number when there is one die roll' do
      die_result.add_roll(3)
      expect(die_result.explain_value).to eql '3'
    end

    it 'should describe all single rolls made and how they combine' do
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

  it 'should combine via +,- and * intuitively based on #value' do
    die_result = GamesDice::DieResult.new(7)
    expect((die_result + 3)).to eql 10
    expect((4 + die_result)).to eql 11
    expect((die_result - 2)).to eql 5
    expect((9 - die_result)).to eql 2

    expect((die_result + 7.7)).to eql 14.7
    expect((4.1 + die_result)).to eql 11.1

    expect((die_result * 2)).to eql 14
    expect((1 * die_result)).to eql 7

    other_die_result = GamesDice::DieResult.new(6)
    other_die_result.add_roll(6, :reroll_add)
    expect((die_result + other_die_result)).to eql 19
    expect((other_die_result - die_result)).to eql 5
  end

  it 'should support comparison with >,<,>=,<= as if it were an integer, based on #value' do
    die_result = GamesDice::DieResult.new(7)

    expect((die_result > 3)).to eql true
    expect((die_result < 14)).to eql true
    expect((die_result >= 7)).to eql true
    expect((die_result <= 9.5)).to eql true
    expect((die_result < 3)).to eql false
    expect((die_result > 14)).to eql false
    expect((die_result <= 8)).to eql true
    expect((die_result >= 14)).to eql false

    other_die_result = GamesDice::DieResult.new(6)
    other_die_result.add_roll(6, :reroll_add)
    expect((die_result > other_die_result)).to eql false
    expect((other_die_result > die_result)).to eql true
    expect((die_result >= other_die_result)).to eql false
    expect((other_die_result >= die_result)).to eql true
    expect((die_result < other_die_result)).to eql true
    expect((other_die_result < die_result)).to eql false
    expect((die_result <= other_die_result)).to eql true
    expect((other_die_result <= die_result)).to eql false
  end

  it 'should sort, based on #value' do
    die_results = [
      GamesDice::DieResult.new(7), GamesDice::DieResult.new(5), GamesDice::DieResult.new(8), GamesDice::DieResult.new(3)
    ]

    die_results.sort!

    expect(die_results[0].value).to eql 3
    expect(die_results[1].value).to eql 5
    expect(die_results[2].value).to eql 7
    expect(die_results[3].value).to eql 8
  end
end
