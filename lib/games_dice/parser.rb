require 'parslet'

# converts string dice descriptions to data usable for the GamesDice::Dice constructor
class GamesDice::Parser < Parslet::Parser

  # Descriptive language examples (capital letters stand in for integers)
  #  NdXk[Z,worst]     -  a roll of N dice, sides X, keep worst Z results and sum them
  #  NdXr[Z,add]       -  a roll of N dice, sides X, re-roll and add on a result of Z
  #  NdXr[Y..Z,add]    -  a roll of N dice, sides X, re-roll and add on a result of Y..Z
  #  NdXm[>=Z,A]       -  mapped dice, values greater than or equal to Z score A (unmapped values score 0 by default)

  # These are the Parslet rules that define the dice grammar
  rule(:integer) { match('[0-9]').repeat(1) }
  rule(:range) { integer.as(:range_start) >> str('..') >> integer.as(:range_end) }
  rule(:dlabel) { match('[d]') }
  rule(:bunch_start) { integer.as(:ndice) >> dlabel >> integer.as(:sides) }

  rule(:reroll_label) { match(['r']).as(:reroll) }
  rule(:keep_label) { match(['k']).as(:keep) }
  rule(:map_label) { match(['m']).as(:map) }
  rule(:alias_label) { match(['x']).as(:alias) }

  rule(:single_modifier) { alias_label }
  rule(:modifier_label) {  reroll_label | keep_label | map_label }
  rule(:simple_modifier) { modifier_label >> integer.as(:simple_value) }
  rule(:complex_modifier) { modifier_label >> str('[') >> str(']') } # TODO: param extraction

  rule(:bunch_modifier) { single_modifier | simple_modifier }
  rule(:bunch) { bunch_start >> bunch_modifier.repeat.as(:mods) }
  rule(:space) { match('\s').repeat(1) }
  rule(:space?) { space.maybe }
  rule(:operator) { match('[+-]').as(:op) >> space? }
  rule(:add_bunch) { operator >> bunch >> space? }
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

      # Modifiers
      if in_hash[:mods]
        in_hash[:mods].each do |mod|
          case
          when mod[:alias]
            collect_alias_modifier mod, out_hash
          when mod[:keep]
            collect_keeper_rule mod, out_hash
          when mod[:map]
            out_hash[:maps] ||= []
            collect_map_rule mod, out_hash
          when mod[:reroll]
            out_hash[:rerolls] ||= []
            collect_reroll_rule mod, out_hash
          end
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

  # Called when we have a single letter convenient alias for common dice adjustments
  def collect_alias_modifier alias_mod, out_hash
    alias_name = alias_mod[:alias].to_s
    case alias_name
    when 'x' # Exploding re-roll
      out_hash[:rerolls] ||= []
      out_hash[:rerolls] << [ out_hash[:sides], :==, :reroll_add ]
    end
  end

  # Called for any parsed reroll rule
  def collect_reroll_rule reroll_mod, out_hash
    out_hash[:rerolls] ||= []
    if reroll_mod[:simple_value]
      out_hash[:rerolls] << [ reroll_mod[:simple_value].to_i, :>=, :reroll_replace, 1 ]
    end
    # TODO: Handle complex descriptions
  end

  # Called for any parsed keeper mode
  def collect_keeper_rule keeper_mod, out_hash
    if keeper_mod[:simple_value]
      out_hash[:keep_mode] = :keep_best
      out_hash[:keep_number] = mod[:simple_value].to_i
      return
    end
    # TODO: Handle complex descriptions
  end

  # Called for any parsed map mode
  def collect_map_rule map_mod, out_hash
    out_hash[:maps] ||= []
    if keeper_mod[:simple_value]
      out_hash[:maps] << GamesDice::MapRule.new( keeper_mod[:simple_value].to_i, :<=, 1 )
      return
    end
    # TODO: Handle complex descriptions
  end

end # class Parser
