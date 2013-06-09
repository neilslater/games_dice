# This class models a variety of game rules that cause dice to be re-rolled.
#
# An object of the class represents a single rule, such as "re-roll a result of 1
# and use the new value".
#
# @example A rule for "exploding" dice
#  rule = GamesDice::RerollRule.new( 6, :<=, :reroll_add )
#  # Test whether the rule applies . . .
#  rule.applies? 4   # => false
#  rule.applies? 6   # => true
#  rule.type         # => :reroll_add
#
# @example A rule for re-rolling and taking best value if first attempt is lower than a threshold
#  rule = GamesDice::RerollRule.new( 11, :>, :reroll_use_best, 1 )
#  # Test whether the rule applies . . .
#  rule.applies? 4   # => true
#  rule.applies? 14  # => false
#  rule.type         # => :reroll_use_best
#

class GamesDice::RerollRule

  # Creates new instance of GamesDice::RerollRule. The rule will be assessed as
  #   trigger_value.send( trigger_op, x )
  # where x is the Integer value shown on a die.
  # @param [Integer,Range<Integer>,Object] trigger_value Any object is allowed, but typically an Integer
  # @param [Symbol] trigger_op A method of trigger_value that takes an Integer param and returns Boolean
  # @param [Symbol] type The type of reroll
  # @param [Integer] limit Maximum number of times this rule can be applied to a single die
  # @return [GamesDice::RerollRule]
  def initialize trigger_value, trigger_op, type, limit = 1000

    if ! trigger_value.respond_to?( trigger_op )
      raise ArgumentError, "trigger_value #{trigger_value.inspect} cannot respond to trigger_op #{trigger_value.inspect}"
    end

    unless GamesDice::REROLL_TYPES.has_key?(type)
      raise ArgumentError, "Unrecognised reason for a re-roll #{type}"
    end

    @trigger_value = trigger_value
    @trigger_op = trigger_op
    @type = type
    @limit = limit ? Integer( limit ) : 1000
    @limit = 1 if @type == :reroll_subtract
  end

  # Trigger operation. How the rule is assessed against #trigger_value.
  # @return [Symbol] Method name to be sent to #trigger_value
  attr_reader :trigger_op

  # Trigger value. An object that will use #trigger_op to assess a die result for a reroll.
  # @return [Integer,Range,Object] Object that receives (#trigger_op, die_result)
  attr_reader :trigger_value

  # The reroll behaviour that this rule triggers.
  # @return [Symbol] A category for the re-roll, declares how it should be processed
  # The following values are supported:
  # +:reroll_add+:: add result of reroll to running total, and ignore :reroll_subtract for this die
  # +reroll_subtract+:: subtract result of reroll from running total, and reverse sense of any further :reroll_add results
  # +:reroll_replace+:: use the new value in place of existing value for the die
  # +:reroll_use_best+:: use the new value if it is higher than the existing value
  # +:reroll_use_worst+:: use the new value if it is higher than the existing value
  attr_reader :type

  # Maximum to number of times that this rule can be applied to a single die.
  # @return [Integer] A number of rolls.
  attr_reader :limit

  # Assesses the rule against a die result value.
  # @param [Integer] test_value Value that is result of rolling a single die.
  # @return [Boolean] Whether the rule applies.
  def applies? test_value
    @trigger_value.send( @trigger_op, test_value ) ? true : false
  end

end # class RerollRule
