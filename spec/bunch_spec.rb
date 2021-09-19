# frozen_string_literal: true

require 'helpers'

describe GamesDice::Bunch do
  describe 'dice scheme' do
    before :each do
      srand(67_809)
    end

    describe '1d10' do
      let(:bunch) { GamesDice::Bunch.new(sides: 10, ndice: 1) }

      it 'should simulate rolling a ten-sided die' do
        [3, 2, 8, 8, 5, 3, 7].each do |expected_total|
          expect(bunch.roll).to eql expected_total
          expect(bunch.result).to eql expected_total
        end
      end

      it 'should concisely explain each result' do
        %w[3 2 8 8].each do |expected_explain|
          bunch.roll
          expect(bunch.explain_result).to eql expected_explain
        end
      end

      it 'should calculate correct min, max = 1,10' do
        expect(bunch.min).to eql 1
        expect(bunch.max).to eql 10
      end

      it 'should have a mean value of 5.5' do
        expect(bunch.probabilities.expected).to be_within(1e-10).of 5.5
      end

      it 'should calculate probabilities correctly' do
        prob_hash = bunch.probabilities.to_h
        expect(prob_hash[1]).to be_within(1e-10).of 0.1
        expect(prob_hash[2]).to be_within(1e-10).of 0.1
        expect(prob_hash[3]).to be_within(1e-10).of 0.1
        expect(prob_hash[4]).to be_within(1e-10).of 0.1
        expect(prob_hash[5]).to be_within(1e-10).of 0.1
        expect(prob_hash[6]).to be_within(1e-10).of 0.1
        expect(prob_hash[7]).to be_within(1e-10).of 0.1
        expect(prob_hash[8]).to be_within(1e-10).of 0.1
        expect(prob_hash[9]).to be_within(1e-10).of 0.1
        expect(prob_hash[10]).to be_within(1e-10).of 0.1
        expect(prob_hash.values.inject(:+)).to be_within(1e-9).of 1.0
      end
    end

    describe '2d6' do
      let(:bunch) { GamesDice::Bunch.new(sides: 6, ndice: 2) }

      it 'should simulate rolling two six-sided dice and adding them' do
        [9, 6, 11, 9, 7, 7, 10].each do |expected_total|
          expect(bunch.roll).to eql expected_total
          expect(bunch.result).to eql expected_total
        end
      end

      it 'should concisely explain each result' do
        ['3 + 6 = 9', '2 + 4 = 6', '5 + 6 = 11', '3 + 6 = 9', '2 + 5 = 7', '6 + 1 = 7',
         '5 + 5 = 10'].each do |expected_explain|
          bunch.roll
          expect(bunch.explain_result).to eql expected_explain
        end
      end

      it 'should calculate correct min, max = 2,12' do
        expect(bunch.min).to eql 2
        expect(bunch.max).to eql 12
      end

      it 'should have a mean value of 7.0' do
        expect(bunch.probabilities.expected).to be_within(1e-10).of 7.0
      end

      it 'should calculate probabilities correctly' do
        prob_hash = bunch.probabilities.to_h
        expect(prob_hash[2]).to be_within(1e-10).of 1 / 36.0
        expect(prob_hash[3]).to be_within(1e-10).of 2 / 36.0
        expect(prob_hash[4]).to be_within(1e-10).of 3 / 36.0
        expect(prob_hash[5]).to be_within(1e-10).of 4 / 36.0
        expect(prob_hash[6]).to be_within(1e-10).of 5 / 36.0
        expect(prob_hash[7]).to be_within(1e-10).of 6 / 36.0
        expect(prob_hash[8]).to be_within(1e-10).of 5 / 36.0
        expect(prob_hash[9]).to be_within(1e-10).of 4 / 36.0
        expect(prob_hash[10]).to be_within(1e-10).of 3 / 36.0
        expect(prob_hash[11]).to be_within(1e-10).of 2 / 36.0
        expect(prob_hash[12]).to be_within(1e-10).of 1 / 36.0
        expect(prob_hash.values.inject(:+)).to be_within(1e-9).of 1.0
      end
    end

    describe '20d10' do
      let(:bunch) { GamesDice::Bunch.new(sides: 10, ndice: 20) }

      it 'should simulate rolling twenty ten-sided dice and adding them' do
        [132, 103, 102, 124, 132, 96, 111].each do |expected_total|
          expect(bunch.roll).to eql expected_total
          expect(bunch.result).to eql expected_total
        end
      end

      it 'should concisely explain each result' do
        explains = ['3 + 2 + 8 + 8 + 5 + 3 + 7 + 7 + 6 + 10 + 7 + 6 + 9 + 5 + 5 + 8 + 10 + 9 + 5 + 9 = 132',
                    '3 + 9 + 1 + 4 + 3 + 5 + 7 + 1 + 10 + 4 + 7 + 7 + 6 + 5 + 2 + 7 + 4 + 9 + 7 + 2 = 103',
                    '6 + 1 + 1 + 3 + 1 + 4 + 9 + 6 + 3 + 10 + 9 + 10 + 8 + 4 + 1 + 4 + 2 + 1 + 10 + 9 = 102']

        explains.each do |expected_explain|
          bunch.roll
          expect(bunch.explain_result).to eql expected_explain
        end
      end

      it 'should calculate correct min, max = 20,200' do
        expect(bunch.min).to eql 20
        expect(bunch.max).to eql 200
      end

      it 'should have a mean value of 110.0' do
        expect(bunch.probabilities.expected).to be_within(1e-8).of 110.0
      end

      it 'should calculate probabilities correctly' do
        prob_hash = bunch.probabilities.to_h
        expect(prob_hash[20]).to be_within(1e-26).of 1e-20
        expect(prob_hash[110]).to be_within(1e-10).of 0.0308191892
        expect(prob_hash.values.inject(:+)).to be_within(1e-9).of 1.0
      end
    end

    describe '4d6 keep best 3' do
      let(:bunch) { GamesDice::Bunch.new(sides: 6, ndice: 4, keep_mode: :keep_best, keep_number: 3) }

      it 'should simulate rolling four six-sided dice and adding the best three values' do
        [13, 17, 13, 12, 13, 10, 14].each do |expected_total|
          expect(bunch.roll).to eql expected_total
          expect(bunch.result).to eql expected_total
        end
      end

      it 'should concisely explain each result' do
        ['3, 6, 2, 4. Keep: 3 + 4 + 6 = 13',
         '5, 6, 3, 6. Keep: 5 + 6 + 6 = 17',
         '2, 5, 6, 1. Keep: 2 + 5 + 6 = 13',
         '5, 5, 2, 1. Keep: 2 + 5 + 5 = 12'].each do |expected_explain|
          bunch.roll
          expect(bunch.explain_result).to eql expected_explain
        end
      end

      it 'should calculate correct min, max = 3,18' do
        expect(bunch.min).to eql 3
        expect(bunch.max).to eql 18
      end

      it 'should have a mean value of roughly 12.2446' do
        expect(bunch.probabilities.expected).to be_within(1e-9).of 12.244598765
      end

      it 'should calculate probabilities correctly' do
        prob_hash = bunch.probabilities.to_h
        expect(prob_hash[3]).to be_within(1e-10).of 1 / 1296.0
        expect(prob_hash[4]).to be_within(1e-10).of 4 / 1296.0
        expect(prob_hash[5]).to be_within(1e-10).of 10 / 1296.0
        expect(prob_hash[6]).to be_within(1e-10).of 21 / 1296.0
        expect(prob_hash[7]).to be_within(1e-10).of 38 / 1296.0
        expect(prob_hash[8]).to be_within(1e-10).of 62 / 1296.0
        expect(prob_hash[9]).to be_within(1e-10).of 91 / 1296.0
        expect(prob_hash[10]).to be_within(1e-10).of 122 / 1296.0
        expect(prob_hash[11]).to be_within(1e-10).of 148 / 1296.0
        expect(prob_hash[12]).to be_within(1e-10).of 167 / 1296.0
        expect(prob_hash[13]).to be_within(1e-10).of 172 / 1296.0
        expect(prob_hash[14]).to be_within(1e-10).of 160 / 1296.0
        expect(prob_hash[15]).to be_within(1e-10).of 131 / 1296.0
        expect(prob_hash[16]).to be_within(1e-10).of 94 / 1296.0
        expect(prob_hash[17]).to be_within(1e-10).of 54 / 1296.0
        expect(prob_hash[18]).to be_within(1e-10).of 21 / 1296.0
        expect(prob_hash.values.inject(:+)).to be_within(1e-9).of 1.0
      end
    end

    describe '10d10 keep worst one' do
      let(:bunch) { GamesDice::Bunch.new(sides: 10, ndice: 10, keep_mode: :keep_worst, keep_number: 1) }

      it 'should simulate rolling ten ten-sided dice and keeping the worst value' do
        [2, 5, 1, 2, 1, 1, 2].each do |expected_total|
          expect(bunch.roll).to eql expected_total
          expect(bunch.result).to eql expected_total
        end
      end

      it 'should concisely explain each result' do
        ['3, 2, 8, 8, 5, 3, 7, 7, 6, 10. Keep: 2',
         '7, 6, 9, 5, 5, 8, 10, 9, 5, 9. Keep: 5',
         '3, 9, 1, 4, 3, 5, 7, 1, 10, 4. Keep: 1',
         '7, 7, 6, 5, 2, 7, 4, 9, 7, 2. Keep: 2'].each do |expected_explain|
          bunch.roll
          expect(bunch.explain_result).to eql expected_explain
        end
      end

      it 'should calculate correct min, max = 1,10' do
        expect(bunch.min).to eql 1
        expect(bunch.max).to eql 10
      end

      it 'should have a mean value of roughly 1.491' do
        expect(bunch.probabilities.expected).to be_within(1e-9).of 1.4914341925
      end

      it 'should calculate probabilities correctly' do
        prob_hash = bunch.probabilities.to_h
        expect(prob_hash[1]).to be_within(1e-10).of 0.6513215599
        expect(prob_hash[2]).to be_within(1e-10).of 0.2413042577
        expect(prob_hash[3]).to be_within(1e-10).of 0.0791266575
        expect(prob_hash[4]).to be_within(1e-10).of 0.0222009073
        expect(prob_hash[5]).to be_within(1e-10).of 0.0050700551
        expect(prob_hash[6]).to be_within(1e-10).of 0.0008717049
        expect(prob_hash[7]).to be_within(1e-10).of 0.0000989527
        expect(prob_hash[8]).to be_within(1e-10).of 0.0000058025
        expect(prob_hash[9]).to be_within(1e-10).of 0.0000001023
        expect(prob_hash[10]).to be_within(1e-18).of 1e-10
        expect(prob_hash.values.inject(:+)).to be_within(1e-9).of 1.0
      end
    end

    describe '5d10, re-roll and add on 10s, keep best 2' do
      let(:bunch) do
        GamesDice::Bunch.new(
          sides: 10, ndice: 5, keep_mode: :keep_best, keep_number: 2,
          rerolls: [GamesDice::RerollRule.new(10, :==, :reroll_add)]
        )
      end

      it "should simulate rolling five ten-sided 'exploding' dice and adding the best two values" do
        [16, 24, 17, 28, 12, 21, 16].each do |expected_total|
          expect(bunch.roll).to eql expected_total
          expect(bunch.result).to eql expected_total
        end
      end

      it 'should concisely explain each result' do
        ['3, 2, 8, 8, 5. Keep: 8 + 8 = 16',
         '3, 7, 7, 6, [10+7] 17. Keep: 7 + 17 = 24',
         '6, 9, 5, 5, 8. Keep: 8 + 9 = 17',
         '[10+9] 19, 5, 9, 3, 9. Keep: 9 + 19 = 28'].each do |expected_explain|
          bunch.roll
          expect(bunch.explain_result).to eql expected_explain
        end
      end

      it 'should calculate correct min, max = 2, > 100' do
        expect(bunch.min).to eql 2
        expect(bunch.max).to be > 100
      end

      it 'should have a mean value of roughly 18.986' do
        expect(bunch.probabilities.expected).to be_within(1e-9).of 18.9859925804
      end

      it 'should calculate probabilities correctly' do
        prob_hash = bunch.probabilities.to_h
        probs = prob_hash.values_at(*2..30)
        expected_probs = [0.00001, 0.00005, 0.00031, 0.00080, 0.00211, 0.00405, 0.00781, 0.01280, 0.02101, 0.0312,
                          0.045715, 0.060830, 0.077915, 0.090080, 0.097935, 0.091230, 0.070015, 0.020480, 0.032805,
                          0.0328, 0.0334626451, 0.0338904805, 0.0338098781, 0.0328226480, 0.0304393461, 0.0260456005,
                          0.0189361531, 0.0082804480, 0.0103524151]

        probs.zip(expected_probs) do |got_prob, expected_prob|
          expect(got_prob).to be_within(1e-10).of(expected_prob)
        end

        expect(prob_hash.values.inject(:+)).to be_within(1e-9).of 1.0
      end
    end

    describe 'roll 2d20, keep best value' do
      let(:bunch) do
        GamesDice::Bunch.new(
          sides: 20, ndice: 2, keep_mode: :keep_best, keep_number: 1
        )
      end

      it 'should simulate rolling two twenty-sided dice and keeping the best value' do
        [19, 18, 14, 6, 13, 10, 16].each do |expected_total|
          expect(bunch.roll).to eql expected_total
          expect(bunch.result).to eql expected_total
        end
      end

      it 'should concisely explain each result' do
        ['19, 14. Keep: 19',
         '18, 16. Keep: 18',
         '5, 14. Keep: 14',
         '3, 6. Keep: 6'].each do |expected_explain|
          bunch.roll
          expect(bunch.explain_result).to eql expected_explain
        end
      end

      it 'should calculate correct min, max = 1,20' do
        expect(bunch.min).to eql 1
        expect(bunch.max).to eql 20
      end

      it 'should have a mean value of 13.825' do
        expect(bunch.probabilities.expected).to be_within(1e-9).of 13.825
      end

      it 'should calculate probabilities correctly' do
        prob_hash = bunch.probabilities.to_h
        expect(prob_hash[1]).to be_within(1e-10).of 1 / 400.0
        expect(prob_hash[2]).to be_within(1e-10).of 3 / 400.0
        expect(prob_hash[3]).to be_within(1e-10).of 5 / 400.0
        expect(prob_hash[4]).to be_within(1e-10).of 7 / 400.0
        expect(prob_hash[5]).to be_within(1e-10).of 9 / 400.0
        expect(prob_hash[6]).to be_within(1e-10).of 11 / 400.0
        expect(prob_hash[7]).to be_within(1e-10).of 13 / 400.0
        expect(prob_hash[8]).to be_within(1e-10).of 15 / 400.0
        expect(prob_hash[9]).to be_within(1e-10).of 17 / 400.0
        expect(prob_hash[10]).to be_within(1e-10).of 19 / 400.0
        expect(prob_hash[11]).to be_within(1e-10).of 21 / 400.0
        expect(prob_hash[12]).to be_within(1e-10).of 23 / 400.0
        expect(prob_hash[13]).to be_within(1e-10).of 25 / 400.0
        expect(prob_hash[14]).to be_within(1e-10).of 27 / 400.0
        expect(prob_hash[15]).to be_within(1e-10).of 29 / 400.0
        expect(prob_hash[16]).to be_within(1e-10).of 31 / 400.0
        expect(prob_hash[17]).to be_within(1e-10).of 33 / 400.0
        expect(prob_hash[18]).to be_within(1e-10).of 35 / 400.0
        expect(prob_hash[19]).to be_within(1e-10).of 37 / 400.0
        expect(prob_hash[20]).to be_within(1e-10).of 39 / 400.0
        expect(prob_hash.values.inject(:+)).to be_within(1e-9).of 1.0
      end
    end

    describe 'roll 2d20, keep worst value' do
      let(:bunch) do
        GamesDice::Bunch.new(
          sides: 20, ndice: 2, keep_mode: :keep_worst, keep_number: 1
        )
      end

      it 'should simulate rolling two twenty-sided dice and keeping the best value' do
        [14, 16, 5, 3, 7, 5, 9].each do |expected_total|
          expect(bunch.roll).to eql expected_total
          expect(bunch.result).to eql expected_total
        end
      end

      it 'should concisely explain each result' do
        ['19, 14. Keep: 14',
         '18, 16. Keep: 16',
         '5, 14. Keep: 5',
         '3, 6. Keep: 3'].each do |expected_explain|
          bunch.roll
          expect(bunch.explain_result).to eql expected_explain
        end
      end

      it 'should calculate correct min, max = 1,20' do
        expect(bunch.min).to eql 1
        expect(bunch.max).to eql 20
      end

      it 'should have a mean value of 7.175' do
        expect(bunch.probabilities.expected).to be_within(1e-9).of 7.175
      end

      it 'should calculate probabilities correctly' do
        prob_hash = bunch.probabilities.to_h
        expect(prob_hash[1]).to be_within(1e-10).of 39 / 400.0
        expect(prob_hash[2]).to be_within(1e-10).of 37 / 400.0
        expect(prob_hash[3]).to be_within(1e-10).of 35 / 400.0
        expect(prob_hash[4]).to be_within(1e-10).of 33 / 400.0
        expect(prob_hash[5]).to be_within(1e-10).of 31 / 400.0
        expect(prob_hash[6]).to be_within(1e-10).of 29 / 400.0
        expect(prob_hash[7]).to be_within(1e-10).of 27 / 400.0
        expect(prob_hash[8]).to be_within(1e-10).of 25 / 400.0
        expect(prob_hash[9]).to be_within(1e-10).of 23 / 400.0
        expect(prob_hash[10]).to be_within(1e-10).of 21 / 400.0
        expect(prob_hash[11]).to be_within(1e-10).of 19 / 400.0
        expect(prob_hash[12]).to be_within(1e-10).of 17 / 400.0
        expect(prob_hash[13]).to be_within(1e-10).of 15 / 400.0
        expect(prob_hash[14]).to be_within(1e-10).of 13 / 400.0
        expect(prob_hash[15]).to be_within(1e-10).of 11 / 400.0
        expect(prob_hash[16]).to be_within(1e-10).of 9 / 400.0
        expect(prob_hash[17]).to be_within(1e-10).of 7 / 400.0
        expect(prob_hash[18]).to be_within(1e-10).of 5 / 400.0
        expect(prob_hash[19]).to be_within(1e-10).of 3 / 400.0
        expect(prob_hash[20]).to be_within(1e-10).of 1 / 400.0
        expect(prob_hash.values.inject(:+)).to be_within(1e-9).of 1.0
      end
    end
  end
end
