require 'parslet'

# Based on the parslet gem, this class defines the dice mini-language used by GamesDice.create
#
# An instance of this class is a parser for the language. There are no user-definable instance
# variables.
#

class GamesDice::Parser < Parslet::Parser

  # Parslet rules that define the dice string grammar.
  rule(:integer) { match('[0-9]').repeat(1) }
  rule(:plus_minus_integer) { ( match('[+-]') >> integer ) | integer }
  rule(:range) { integer.as(:range_start) >> str('..') >> integer.as(:range_end) }
  rule(:dlabel) { match('[d]') }
  rule(:space) { match('\s').repeat(1) }
  rule(:space?) { space.maybe }
  rule(:underscore) { str('_').repeat(1) }
  rule(:underscore?) { space.maybe }

  rule(:bunch_start) { integer.as(:ndice) >> dlabel >> integer.as(:sides) }

  rule(:reroll_label) { match(['r']).as(:reroll) }
  rule(:keep_label) { match(['k']).as(:keep) }
  rule(:map_label) { match(['m']).as(:map) }
  rule(:alias_label) { match(['x']).as(:alias) }

  rule(:single_modifier) { alias_label }
  rule(:modifier_label) {  reroll_label | keep_label | map_label }
  rule(:simple_modifier) { modifier_label >> integer.as(:simple_value) }
  rule(:comparison_op) { str('>=') | str('<=') | str('==') | str('>') | str('<') }
  rule(:ctl_string) { match('[a-z_]').repeat(1) }
  rule(:output_string) { match('[A-Za-z0-9_]').repeat(1) }

  rule(:opint_or_int) { (comparison_op.as(:comparison) >> integer.as(:compare_num)) | integer.as(:compare_num) }
  rule(:comma) { str(',') }
  rule(:stop) { str('.') }

  rule(:condition_only) { opint_or_int.as(:condition) }
  rule(:num_only) { integer.as(:num) }


  rule(:condition_and_type) { opint_or_int.as(:condition) >> comma >> ctl_string.as(:type) }
  rule(:condition_and_num) { opint_or_int.as(:condition) >> comma >> plus_minus_integer.as(:num) }

  rule(:condition_type_and_num) { opint_or_int.as(:condition) >> comma >> ctl_string.as(:type) >> comma >> integer.as(:num) }
  rule(:condition_num_and_output) { opint_or_int.as(:condition) >> comma >> plus_minus_integer.as(:num) >> comma >> output_string.as(:output) }
  rule(:num_and_type) { integer.as(:num)  >> comma >> ctl_string.as(:type) }

  rule(:reroll_params) { condition_type_and_num | condition_and_type | condition_only }
  rule(:map_params) { condition_num_and_output | condition_and_num | condition_only }
  rule(:keeper_params) { num_and_type | num_only }

  rule(:full_reroll) { reroll_label >> str(':') >> reroll_params >> stop }
  rule(:full_map) { map_label >> str(':') >> map_params >> stop }
  rule(:full_keepers) { keep_label >> str(':') >> keeper_params >> stop }

  rule(:complex_modifier) { full_reroll | full_map | full_keepers }

  rule(:bunch_modifier) { complex_modifier | ( single_modifier >> stop.maybe ) | ( simple_modifier >> stop.maybe ) }
  rule(:bunch) { bunch_start >> bunch_modifier.repeat.as(:mods) }

  rule(:operator) { match('[+-]').as(:op) >> space? }
  rule(:add_bunch) { operator >> bunch >> space? }
  rule(:add_constant) { operator >> integer.as(:constant) >> space? }
  rule(:dice_expression) { add_bunch | add_constant }
  rule(:expressions) { dice_expression.repeat.as(:bunches) }
  root :expressions

  # Parses a string description in the dice mini-language, and returns data for feeding into
  # GamesDice::Dice constructore.
  # @param [String] dice_description Text to parse e.g. '1d6'
  # @return [Hash] Analysis of dice_description
  def parse dice_description
    dice_description = dice_description.to_s.strip
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
      out_hash[:rerolls] << [ reroll_mod[:simple_value].to_i, :>=, :reroll_replace ]
      return
    end

    # Typical reroll_mod: {:reroll=>"r"@5, :condition=>{:compare_num=>"10"@7}, :type=>"add"@10}
    op = get_op_symbol( reroll_mod[:condition][:comparison] || '==' )
    v = reroll_mod[:condition][:compare_num].to_i
    type = ( 'reroll_' + ( reroll_mod[:type] || 'replace' ) ).to_sym

    if reroll_mod[:num]
      out_hash[:rerolls] << [ v, op, type, reroll_mod[:num].to_i ]
    else
      out_hash[:rerolls] << [ v, op, type ]
    end
  end

  # Called for any parsed keeper mode
  def collect_keeper_rule keeper_mod, out_hash
    raise "Cannot set keepers for a bunch twice" if out_hash[:keep_mode]
    if keeper_mod[:simple_value]
      out_hash[:keep_mode] = :keep_best
      out_hash[:keep_number] = keeper_mod[:simple_value].to_i
      return
    end

    # Typical keeper_mod: {:keep=>"k"@5, :num=>"1"@7, :type=>"worst"@9}
    out_hash[:keep_number] = keeper_mod[:num].to_i
    out_hash[:keep_mode] = ( 'keep_' + ( keeper_mod[:type] || 'best' ) ).to_sym
  end

  # Called for any parsed map mode
  def collect_map_rule map_mod, out_hash
    out_hash[:maps] ||= []
    if map_mod[:simple_value]
      out_hash[:maps] << [ map_mod[:simple_value].to_i, :<=, 1 ]
      return
    end

    # Typical map_mod: {:map=>"m"@4, :condition=>{:compare_num=>"5"@6}, :num=>"2"@8, :output=>"Qwerty"@10}
    op = get_op_symbol( map_mod[:condition][:comparison] || '>=' )
    v = map_mod[:condition][:compare_num].to_i
    out_val = 1
    if map_mod[:num]
      out_val = map_mod[:num].to_i
    end

    if map_mod[:output]
      out_hash[:maps] << [ v, op, out_val, map_mod[:output].to_s ]
    else
      out_hash[:maps] << [ v, op, out_val ]
    end
  end

  # The dice description language uses (r).op.x, whilst GamesDice::RerollRule uses x.op.(r), so
  # as well as converting to a symbol, we must reverse sense of input to constructor
  OP_CONVERSION = {
    '==' => :==,
    '>=' => :<=,
    '>' => :<,
    '<' => :>,
    '<=' => :>=,
  }

  def get_op_symbol parsed_op_string
    OP_CONVERSION[ parsed_op_string.to_s ]
  end

end # class Parser
