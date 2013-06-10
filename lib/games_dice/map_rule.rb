# This class models rules that convert numbers shown on a die to values used in a game. A
# common use for this is to count "successes" - dice that score a certain number or higher.
#
# An object of the class represents a single rule, such as "count a die result of 5 or more as 1
# _success_".
#
# @example A rule for counting successes
#  rule = GamesDice::MapRule.new( 6, :<=, 1, 'Success' )
#  # Test how the rule applies . . .
#  rule.map_from 4   # => nil
#  rule.map_from 6   # => 1
#
# @example A rule for counting "fumbles" which reduce total successes
#  rule = GamesDice::MapRule.new( 1, :==, -1, 'Fumble' )
#  # Test how the rule applies . . .
#  rule.map_from 7   # => nil
#  rule.map_from 1   # => -1
#

class GamesDice::MapRule

  # Creates new instance of GamesDice::MapRule. The rule will be assessed as
  #   trigger_value.send( trigger_op, x )
  # where x is the Integer value shown on a die.
  # @param [Integer,Range<Integer>,Object] trigger_value Any object is allowed, but typically an Integer
  # @param [Symbol] trigger_op A method of trigger_value that takes an Integer param and returns Boolean
  # @param [Integer] mapped_value The value to use in place of the trigger value
  # @param [String] mapped_name Name of mapped value, for use in descriptions
  # @return [GamesDice::MapRule]
  def initialize trigger_value, trigger_op, mapped_value=0, mapped_name=''

    if ! trigger_value.respond_to?( trigger_op )
      raise ArgumentError, "trigger_value #{trigger_value.inspect} cannot respond to trigger_op #{trigger_value.inspect}"
    end

    @trigger_value = trigger_value
    @trigger_op = trigger_op
    raise TypeError if ! mapped_value.is_a? Numeric
    @mapped_value = Integer(mapped_value)
    @mapped_name = mapped_name.to_s
  end

  # Trigger operation. How the rule is assessed against #trigger_value.
  # @return [Symbol] Method name to be sent to #trigger_value
  attr_reader :trigger_op

  # Trigger value. An object that will use #trigger_op to assess a die result for a reroll.
  # @return [Integer,Range,Object] Object that receives (#trigger_op, die_result)
  attr_reader :trigger_value

  # Mapped value.
  # @return [Integer]
  attr_reader :mapped_value

  # Name for mapped value.
  # @return [String]
  attr_reader :mapped_name

  # Assesses the rule against a die result value.
  # @param [Integer] test_value Value that is result of rolling a single die.
  # @return [Integer,nil] Replacement value, or nil if this rule doesn't apply
  def map_from test_value
    op_result = @trigger_value.send( @trigger_op, test_value )
    return nil unless op_result
    if op_result == true
      return @mapped_value
    end
    return op_result
  end
end # class MapRule
