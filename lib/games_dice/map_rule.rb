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

  # trigger_op, trigger_value, mapped_value and mapped_name set the attributes of the same name
  #  rule = RPGMapRule.new( 6, :<=, 1, 'Success' ) # score 1 for a result of 6 or more
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

  # an Integer value or Range that will be mapped to a single value. #trigger_op is called against it
  attr_reader :trigger_value

  # a valid symbol for a method, which will be called against #trigger_value with the current
  # die result as a param. If the operator returns true for a specific die result, then the
  # mapped_value will be used in its stead. If the operator returns nil or false, the map is not
  # triggered. All other values will be returned as the result of the map (allowing you to
  # specify any method that takes an integer as input and returns something else as the end result)
  attr_reader :trigger_op

  # an integer value
  attr_reader :mapped_value

  # a string description of the mapping, e.g. 'S' for a success
  attr_reader :mapped_name

  # runs the rule against test_value, returning either a new value, or nil if the rule does not apply
  def map_from test_value
    op_result = @trigger_value.send( @trigger_op, test_value )
    return nil unless op_result
    if op_result == true
      return @mapped_value
    end
    return op_result
  end
end # class MapRule
