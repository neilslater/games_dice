# specifies when and how a ComplexDie should be re-rolled
class GamesDice::RerollRule

  # trigger_op, trigger_value, type and limit set the attributes of the same name
  #  rule = GamesDice::RerollRule.new( 10, :<=, :reroll_add ) # an 'exploding' die
  def initialize trigger_value, trigger_op, type, limit=nil

    if ! trigger_value.respond_to?( trigger_op )
      raise ArgumentError, "trigger_value #{trigger_value.inspect} cannot respond to trigger_op #{trigger_value.inspect}"
    end

    unless GamesDice::REROLL_TYPES.has_key?(type)
      raise ArgumentError, "Unrecognised reason for a re-roll #{type}"
    end

    @trigger_value = trigger_value
    @trigger_op = trigger_op
    @type = type
    @limit = limit ? Integer(limit) : 1000
    @limit = 1 if @type == :reroll_subtract
  end

  # a valid symbol for a method, which will be called against #trigger_value with the current
  # die result as a param. It should return true or false
  attr_reader :trigger_op

  # an Integer value or Range that will cause the reroll to occur. #trigger_op is called against it
  attr_reader :trigger_value

  # a symbol, should be one of the following:
  #   :reroll_add - add result of reroll to running total, and ignore :reroll_subtract for this die
  #   :reroll_subtract - subtract result of reroll from running total, and reverse sense of any further :reroll_add results
  #   :reroll_replace - use the new value in place of existing value for the die
  #   :reroll_use_best - use the new value if it is higher than the existing value
  #   :reroll_use_worst - use the new value if it is higher than the existing value
  attr_reader :type

  # maximum number of times this rule should be applied to a single die. If type is:reroll_subtract,
  # this value is always 1. A default value of 100 is used if not set in the constructor
  attr_reader :limit

  # runs the rule against a test value, returning truth value from calling the trigger_op method
  def applies? test_value
    @trigger_value.send( @trigger_op, test_value ) ? true : false
  end

end # class RerollRule
