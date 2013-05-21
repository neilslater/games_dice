# models any combination of zero or more Bunches, plus a constant offset, summing them
# to create a total result when rolled
class GamesDice::Dice
  # bunches is an Array of Hashes, each of which describes a GamesDice::Bunch
  # and may contain any of the keys that can be used to initialize
  # the Bunch, plus the following optional key:
  #  :multiplier => any Integer, but typically 1 or -1 to describe whether the Bunch total is to be added or subtracted
  # offset is an Integer which will be added to the result when rolling all the bunches
  # name can be any String, and is used to identify the dice being rolled.
  def initialize( bunches, offset = 0, name = '' )
    @name = name
    @offset = offset
    @bunches = bunches.map { |b| GamesDice::Bunch.new( b ) }
    @bunch_multipliers = bunches.map { |b| b[:multiplier] || 1 }
    @result = nil
  end

  # the string name as provided to the constructor, it will appear in explain_result
  attr_reader :name

  # an array of GamesDice::Bunch objects that together describe all the dice and roll-altering
  # rules that apply to the GamesDice::Dice object
  attr_reader :bunches

  # an array of Integers, used to multiply result from each bunch when total results are summed
  attr_reader :bunch_multipliers

  # the integer offset that is added to the total result from all bunches
  attr_reader :offset

  # after calling #roll, this is set to the total integer value as calculated by simulating all the
  # defined dice and their rules
  attr_reader :result

  # simulate dice roll. Returns integer final total, and also stores same value in #result
  def roll
    @result = @offset + @bunch_multipliers.zip(@bunches).inject(0) do |total,mb|
      m,b = mb
      total += m * b.roll
    end
  end

  def min
    @min ||= @offset + @bunch_multipliers.zip(@bunches).inject(0) do |total,mb|
      m,b = mb
      total += m * b.min
    end
  end

  def max
    @max ||= @offset + @bunch_multipliers.zip(@bunches).inject(0) do |total,mb|
      m,b = mb
      total += m * b.max
    end
  end

  def minmax
    [min,max]
  end

  def probabilities
    return @probabilities if @probabilities
    probs = @bunch_multipliers.zip(@bunches).inject( GamesDice::Probabilities.new( { @offset => 1.0 } ) ) do |probs, mb|
      m,b = mb
      GamesDice::Probabilities.add_distributions_mult( 1, probs, m, b.probabilities )
    end
  end

end # class Dice
