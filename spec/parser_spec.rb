require 'games_dice'

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

    it "should parse 'NdXrY as 'roll N dice of X sides, re-roll a Y or less once'" do
      variations = {
        '1d6r1' => { :bunches => [{:ndice=>1, :sides=>6, :multiplier=>1, :rerolls=>[ [1,:>=,:reroll_replace,1] ]}], :offset => 0 },
        '2d20r7' => { :bunches => [{:ndice=>2, :sides=>20, :multiplier=>1, :rerolls=>[ [7,:>=,:reroll_replace,1] ]}], :offset => 0 },
        '1d8r2' => { :bunches => [{:ndice=>1, :sides=>8, :multiplier=>1, :rerolls=>[ [2,:>=,:reroll_replace,1] ]}], :offset => 0 },
      }

      variations.each do |input,expected_output|
        parser.parse( input ).should ==  expected_output
      end
    end

  end # describe "#parse"
end
