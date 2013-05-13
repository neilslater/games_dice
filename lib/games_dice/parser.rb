require 'parslet'

# converts string dice descriptions to data usable for the GamesDice::Dice constructor
class GamesDice::Parser < Parslet::Parser

  # Descriptive language examples (capital letters stand in for integers)
  #  NdX               -  a roll of N dice, with X sides each, values summed to total
  #  NdX + C           -  a roll of N dice, with X sides each, values summed to total plus a constant C
  #  NdX - C           -  a roll of N dice, with X sides each, values summed to total minus a constant C
  #  NdX + MdY + C     -  any number of +C, -C, +NdX, -NdX etc sub-expressions can be combined
  #  NdXkZ             -  a roll of N dice, sides X, keep best Z results and sum them
  #  NdXk[Z,worst]     -  a roll of N dice, sides X, keep worst Z results and sum them
  #  NdXrZ             -  a roll of N dice, sides X, re-roll and replace Zs
  #  NdXr[Z,add]       -  a roll of N dice, sides X, re-roll and add on a result of Z
  #  NdXr[Y..Z,add]    -  a roll of N dice, sides X, re-roll and add on a result of Y..Z
  #  NdXx              -  exploding dice, synonym for NdXr[X,add]
  #  NdXmZ             -  mapped dice, values below Z score 0, values above Z score 1
  #  NdXm[>=Z,A]       -  mapped dice, values greater than or equal to Z score A (unmapped values score 0 by default)

  # These are the Parslet rules that define the dice grammar
  rule(:integer) { match('[0-9]').repeat(1) }
  rule(:dlabel) { match('[d]') }
  rule(:bunch_start) { integer.as(:ndice) >> dlabel >> integer.as(:sides) }
  rule(:space) { match('\s').repeat(1) }
  rule(:space?) { space.maybe }
  rule(:operator) { match('[+-]').as(:op) >> space? }
  rule(:add_bunch) { operator >> bunch_start >> space? }
  rule(:add_constant) { operator >> integer.as(:constant) >> space? }
  rule(:dice_expression) { add_bunch | add_constant }
  rule(:expressions) { dice_expression.repeat.as(:bunches) }
  root :expressions

  def parse dice_description, dice_name = nil
    dice_description = dice_description.to_s.strip
    dice_name ||= dice_description
    # Force first item to start '+' for simpler parse rules
    dice_description = '+' + dice_description unless dice_description =~ /\A[+-]/
    dice_expressions = super( dice_description )

    { :bunches => collect_bunches( dice_expressions ), :offset => collect_offset( dice_expressions ) }
  end

  private

  def collect_bunches dice_expressions
    dice_expressions[:bunches].select {|h| h[:ndice] }.map do |in_hash|
      out_hash = {}
      # Convert integers
      [:ndice, :sides].each do |s|
        next unless in_hash[s]
        out_hash[s] = in_hash[s].to_i
      end

      # Multiplier
      if in_hash[:op]
        optype = in_hash[:op].to_s
        out_hash[:multiplier] = case optype
          when '+' then 1
          when '-' then -1
        end
      end
      out_hash
    end
  end

  def collect_offset dice_expressions
    dice_expressions[:bunches].select {|h| h[:constant] }.inject(0) do |total, in_hash|
      c = in_hash[:constant].to_i
      optype = in_hash[:op].to_s
      if optype == '+'
        total += c
      else
        total -= c
      end
      total
    end
  end

end # class Parser
