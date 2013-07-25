require 'helpers'

describe GamesDice::Parser do

  describe "#parse" do
    let(:parser) { GamesDice::Parser.new }

    it "should parse simple dice sums" do
      variations = {
        '1d6' => { :bunches => [{:ndice=>1, :sides=>6, :multiplier=>1}], :offset => 0 },
        '2d8-1d4' => { :bunches => [{:ndice=>2, :sides=>8, :multiplier=>1},{:ndice=>1, :sides=>4, :multiplier=>-1}], :offset => 0 },
        '+ 2d10 - 1d4 ' => { :bunches => [{:ndice=>2, :sides=>10, :multiplier=>1},{:ndice=>1, :sides=>4, :multiplier=>-1}], :offset => 0 },
        ' + 3d6 + 12 ' => { :bunches => [{:ndice=>3, :sides=>6, :multiplier=>1}], :offset => 12 },
        '-7 + 2d4 + 1 ' => { :bunches => [{:ndice=>2, :sides=>4, :multiplier=>1}], :offset => -6 },
        '- 3 + 7d20 - 1 ' => { :bunches => [{:ndice=>7, :sides=>20, :multiplier=>1}], :offset => -4 },
        ' -   2d4' => { :bunches => [{:ndice=>2, :sides=>4, :multiplier=>-1}], :offset => 0 },
        '3d12+5+2d8+1d6' => { :bunches => [{:ndice=>3, :sides=>12, :multiplier=>1},{:ndice=>2, :sides=>8, :multiplier=>1},{:ndice=>1, :sides=>6, :multiplier=>1}], :offset => 5 },
      }

      variations.each do |input,expected_output|
        parser.parse( input ).should ==  expected_output
      end
    end

    it "should parse 'NdXrY' as 'roll N times X-sided dice, re-roll and replace a Y or less (once)'" do
      variations = {
        '1d6r1' => { :bunches => [{:ndice=>1, :sides=>6, :multiplier=>1, :rerolls=>[ [1,:>=,:reroll_replace] ]}], :offset => 0 },
        '2d20r7' => { :bunches => [{:ndice=>2, :sides=>20, :multiplier=>1, :rerolls=>[ [7,:>=,:reroll_replace] ]}], :offset => 0 },
        '1d8r2' => { :bunches => [{:ndice=>1, :sides=>8, :multiplier=>1, :rerolls=>[ [2,:>=,:reroll_replace] ]}], :offset => 0 },
      }

      variations.each do |input,expected_output|
        parser.parse( input ).should ==  expected_output
      end
    end

    it "should parse 'NdXmZ' as 'roll N times X-sided dice, a value of Z or more equals 1 (success)'" do
      variations = {
        '5d6m6' => { :bunches => [{:ndice=>5, :sides=>6, :multiplier=>1, :maps=>[ [6,:<=,1] ]}], :offset => 0 },
        '2d10m7' => { :bunches => [{:ndice=>2, :sides=>10, :multiplier=>1, :maps=>[ [7,:<=,1] ]}], :offset => 0 },
      }

      variations.each do |input,expected_output|
        parser.parse( input ).should ==  expected_output
      end
    end

    it "should parse 'NdXkC' as 'roll N times X-sided dice, add together the best C'" do
      variations = {
        '5d10k3' => { :bunches => [{:ndice=>5, :sides=>10, :multiplier=>1, :keep_mode=>:keep_best, :keep_number=>3}], :offset => 0 },
      }

      variations.each do |input,expected_output|
        parser.parse( input ).should ==  expected_output
      end
    end

    it "should parse 'NdXx' as 'roll N times X-sided *exploding* dice'" do
      variations = {
        '5d10x' => { :bunches => [{:ndice=>5, :sides=>10, :multiplier=>1, :rerolls=>[ [10,:==,:reroll_add] ]}], :offset => 0 },
        '3d6x' => { :bunches => [{:ndice=>3, :sides=>6, :multiplier=>1, :rerolls=>[ [6,:==,:reroll_add] ]}], :offset => 0 },
      }

      variations.each do |input,expected_output|
        parser.parse( input ).should ==  expected_output
      end
    end

    it "should successfully parse combinations of modifiers in any valid order" do
      variations = {
        '5d10r1x' => { :bunches => [{:ndice=>5, :sides=>10, :multiplier=>1, :rerolls=>[ [1,:>=,:reroll_replace], [10,:==,:reroll_add] ]}], :offset => 0 },
        '3d6xk2' => { :bunches => [{:ndice=>3, :sides=>6, :multiplier=>1, :rerolls=>[ [6,:==,:reroll_add] ], :keep_mode=>:keep_best, :keep_number=>2 }], :offset => 0 },
        '4d6m8x' => { :bunches => [{:ndice=>4, :sides=>6, :multiplier=>1, :maps=>[ [8,:<=,1] ], :rerolls=>[ [6,:==,:reroll_add] ] }], :offset => 0 },
      }

      variations.each do |input,expected_output|
        parser.parse( input ).should ==  expected_output
      end
    end

  end # describe "#parse"
end
