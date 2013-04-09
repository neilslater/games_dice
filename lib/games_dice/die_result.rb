# returned by any complex die roll (i.e. one that may be subject to re-rolls or adjustments to each die)
#  dr = GamesDice::DieResult.new
#  dr.add_roll(5)
#  dr.add_roll(4,:reroll_add)
#  dr.value # => 9
#  dr.rolls # => [5,4]
#  dr.roll_reasons # => [:basic,:reroll_add]
#  dr + 5 # => 14
# As the last example implies, GamesDice::DieResult objects coerce to the #value attribute
class GamesDice::DieResult
  include Comparable

  # allowed reasons for making a roll, and symbol to use before number in #explain
  REASONS = {
    :basic => ',',
    :reroll_add => '+',
    :reroll_new_die => '*', # TODO: This needs to be flagged *before* value, and maybe linked to cause
    :reroll_new_keeper => '*',
    :reroll_subtract => '-',
    :reroll_replace => '|',
    :reroll_use_best => '/',
    :reroll_use_worst => '\\',
  }

  # first_roll_result is optional value of first roll of the die
  def initialize( first_roll_result=nil, first_roll_reason=:basic )
    unless REASONS.has_key?(first_roll_reason)
      raise ArgumentError, "Unrecognised reason for roll #{first_roll_reason}"
    end

    if (first_roll_result)
      @rolls = [Integer(first_roll_result)]
      @roll_reasons = [first_roll_reason]
      @total = @rolls[0]
    else
      @rolls = []
      @roll_reasons = []
      @total = nil
    end
    @mapped = false
    @value = @total
  end

  public

  # array of integers
  attr_reader :rolls

  # array of symbol reasons for making roll
  attr_reader :roll_reasons

  # combined numeric value of all rolls, nil if nothing calculated yet. Often the same number as
  # #result, but may be different if there has been a call to #apply_map
  attr_reader :total

  # overall result of applying all rolls, nil if nothing calculated yet
  attr_reader :value

  # true if #apply_map has been called, and no more roll results added since
  attr_reader :mapped

  # stores the value of a simple die roll. roll_result should be an Integer,
  # roll_reason is an optional symbol description of why the roll was made
  # #total and #value are calculated based on roll_reason
  def add_roll( roll_result, roll_reason=:basic )
    unless REASONS.has_key?(roll_reason)
      raise ArgumentError, "Unrecognised reason for roll #{roll_reason}"
    end
    @rolls << Integer(roll_result)
    @roll_reasons << roll_reason
    if @rolls.length == 1
      @total = 0
    end

    case roll_reason
    when :basic
      @total = roll_result
    when :reroll_add
      @total += roll_result
    when :reroll_subtract
      @total -= roll_result
    when :reroll_new_die
      @total = roll_result
    when :reroll_new_keeper
      @total = roll_result
    when :reroll_replace
      @total = roll_result
    when :reroll_use_best
      @total = [@value,roll_result].max
    when :reroll_use_worst
      @total = [@value,roll_result].min
    end

    @mapped = false
    @value = @total
  end

  # sets #value arbitrarily intended for use by GamesDice::MapRule objects
  def apply_map( to_value, description = '' )
    @mapped = true
    @value = to_value
    @map_description = description
  end

  # returns a string summary of how #value was obtained, showing all contributing rolls
  def explain_value
    text = ''
    if @rolls.length < 2
      text = @total.to_s
    else
      text = '[' + @rolls[0].to_s
      text = (1..@rolls.length-1).inject( text ) { |so_far,i| so_far + REASONS[@roll_reasons[i]] + @rolls[i].to_s }
      text += '] ' + @total.to_s
    end
    text += ' ' + @map_description if @mapped && @map_description && @map_description.length > 0
    return text
  end

  # returns a string summary of the #total, including effect of any maps that been applied
  def explain_total
    text = @total.to_s
    text += ' ' + @map_description if @mapped && @map_description && @map_description.length > 0
    return text
  end

  # all coercions simply use #value (i.e. nil or a Fixnum)
  def coerce(thing)
    @value.coerce(thing)
  end

  # addition uses #value
  def +(thing)
    @value + thing
  end

  # subtraction uses #value
  def -(thing)
    @value - thing
  end

  # multiplication uses #value
  def *(thing)
    @value * thing
  end

  # comparison <=> uses #value
  def <=>(other)
    self.value <=> other
  end

  # implements a deep clone (used for recursive probability calculations)
  def clone
    cloned = GamesDice::DieResult.new()
    cloned.instance_variable_set('@rolls', @rolls.clone)
    cloned.instance_variable_set('@roll_reasons', @roll_reasons.clone)
    cloned.instance_variable_set('@total', @total)
    cloned.instance_variable_set('@value', @value)
    cloned.instance_variable_set('@mapped', @mapped)
    cloned.instance_variable_set('@map_description', @map_description)
    cloned
  end
end
