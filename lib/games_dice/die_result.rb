# frozen_string_literal: true

module GamesDice
  # This class models the output of GamesDice::ComplexDie.
  #
  # An object of the class represents the results of a roll of a ComplexDie, including any re-rolls and
  # value mapping.
  #
  # @example Building up a result manually
  #  dr = GamesDice::DieResult.new
  #  dr.add_roll 5
  #  dr.add_roll 4, :reroll_replace
  #  dr.value # => 4
  #  dr.rolls # => [5, 4]
  #  dr.roll_reasons # => [:basic, :reroll_replace]
  #  # dr can behave as dr.value due to coercion and support for some operators
  #  dr + 6 # => 10
  #
  # @example Using a result from GamesDice::ComplexDie
  #  # An "exploding" six-sided die that needs a result of 8 to score "1 Success"
  #  d = GamesDice::ComplexDie.new( 6, :rerolls => [[6, :<=, :reroll_add]], :maps => [[8, :<=, 1, 'Success']] )
  #  # Generate result object by rolling the die
  #  dr = d.roll
  #  dr.rolls         # => [6, 3]
  #  dr.roll_reasons  # => [:basic, :reroll_add]
  #  dr.total         # => 9
  #  dr.value         # => 1
  #  dr.explain_value # => "[6+3] 9 Success"
  #
  class DieResult
    include Comparable

    # Creates new instance of GamesDice::DieResult. The object can be initialised "empty" or with a first result.
    # @param [Integer,nil] first_roll_result Value for first roll of the die.
    # @param [Symbol] first_roll_reason Reason for first roll of the die.
    # @return [GamesDice::DieResult]
    def initialize(first_roll_result = nil, first_roll_reason = :basic)
      unless GamesDice::REROLL_TYPES.key?(first_roll_reason)
        raise ArgumentError, "Unrecognised reason for roll #{first_roll_reason}"
      end

      if first_roll_result
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

    # The individual die rolls that combined to generate this result.
    # @return [Array<Integer>] Un-processed values of each die roll used for this result.
    attr_reader :rolls

    # The individual reasons for each roll of the die. See GamesDice::RerollRule for allowed values.
    # @return [Array<Symbol>] Reasons for each die roll, indexes match the #rolls Array.
    attr_reader :roll_reasons

    # Combined result of all rolls, *before* mapping.
    # @return [Integer,nil]
    attr_reader :total

    # Combined result of all rolls, *after* mapping.
    # @return [Integer,nil]
    attr_reader :value

    # Whether or not #value has been mapped from #total.
    # @return [Boolean]
    attr_reader :mapped

    # Adds value from a new roll to the object. GamesDice::DieResult tracks reasons for the roll
    # and makes the correct adjustment to the total so far. Any mapped value is cleared.
    # @param [Integer] roll_result Value result from rolling the die.
    # @param [Symbol] roll_reason Reason for rolling the die.
    # @return [Integer] Total so far
    def add_roll(roll_result, roll_reason = :basic)
      unless GamesDice::REROLL_TYPES.key?(roll_reason)
        raise ArgumentError, "Unrecognised reason for roll #{roll_reason}"
      end

      @rolls << Integer(roll_result)
      @roll_reasons << roll_reason
      @total = 0 if @rolls.length == 1

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
        @total = [@value, roll_result].max
      when :reroll_use_worst
        @total = [@value, roll_result].min
      end

      @mapped = false
      @value = @total
    end

    # Sets value arbitrarily, and notes that the value has been mapped. Used by GamesDice::ComplexDie
    # when there are one or more GamesDice::MapRule objects to process for a die.
    # @param [Integer] to_value Replacement value.
    # @param [String] description Description of what the mapped value represents e.g. "Success"
    # @return [nil]
    def apply_map(to_value, description = '')
      @mapped = true
      @value = to_value
      @map_description = description
      nil
    end

    # Generates a text description of how #value is determined. If #value has been mapped, includes the
    # map description, but does not include the mapped value.
    # @return [String] Explanation of #value.
    def explain_value
      text = ''
      if @rolls.length < 2
        text = @total.to_s
      else
        text = "[#{@rolls[0]}"
        text = (1..@rolls.length - 1).inject(text) do |so_far, i|
          so_far + GamesDice::REROLL_TYPES[@roll_reasons[i]] + @rolls[i].to_s
        end
        text += "] #{@total}"
      end
      text += " #{@map_description}" if @mapped && @map_description && @map_description.length.positive?
      text
    end

    # @!visibility private
    # This is mis-named, it doesn't explain the total at all! It is used to generate summaries of keeper dice.
    def explain_total
      text = @total.to_s
      text += " #{@map_description}" if @mapped && @map_description && @map_description.length.positive?
      text
    end

    # @!visibility private
    # all coercions simply use #value (i.e. nil or a Integer)
    def coerce(thing)
      @value.coerce(thing)
    end

    # @!visibility private
    # addition uses #value
    def +(other)
      @value + other
    end

    # @!visibility private
    # subtraction uses #value
    def -(other)
      @value - other
    end

    # @!visibility private
    # multiplication uses #value
    def *(other)
      @value * other
    end

    # @!visibility private
    # comparison <=> uses #value
    def <=>(other)
      value <=> other
    end

    # This is a deep clone, all attributes are cloned.
    # @return [GamesDice::DieResult]
    def clone
      cloned = GamesDice::DieResult.new
      cloned.instance_variable_set('@rolls', @rolls.clone)
      cloned.instance_variable_set('@roll_reasons', @roll_reasons.clone)
      cloned.instance_variable_set('@total', @total)
      cloned.instance_variable_set('@value', @value)
      cloned.instance_variable_set('@mapped', @mapped)
      cloned.instance_variable_set('@map_description', @map_description)
      cloned
    end
  end
end
