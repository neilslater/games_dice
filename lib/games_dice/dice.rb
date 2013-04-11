# models any combination of zero or more Bunches, plus zero or more constant offsets, summing them
# to create a total
class GamesDice::Dice
  # bunches is an Array of Hashes, each of which describes either a GamesDice::Bunch or a fixed offset
  # a Hash in the Array that describes a fixed offset looks like this:
  #  { :offset => 20 }
  # a Hash in the Array that describes a Bunch may contain any of the keys that can be used to initialize
  # the Bunch, plus the following optional key:
  #  :multiplier => any Integer, but typically 1 or -1 to allow the Bunch total to be added or subtracted
  # name can be any String, and is used to identify the dice being rolled.
  def initialize( bunches, name = '' )
    @name = name
    @offset = 0
    @bunches = []
  end

  # the string name as provided to the constructor, it will appear in explain_result
  attr_reader :name

  # after calling #roll, this is set to the final integer value from using the dice as specified
  attr_reader :result

  # minimum possible integer value
  def min
    n = @keep_mode ? [@keep_number,@ndice].min : @ndice
    return n * @single_die.min
  end

  # maximum possible integer value
  def max
    n = @keep_mode ? [@keep_number,@ndice].min : @ndice
    return n * @single_die.max
  end

  # returns mean expected value as a Float
  def expected_result
    @expected_result ||= probabilities.inject(0.0) { |accumulate,p| accumulate + p[0] * p[1] }
  end

  # simulate dice roll according to spec. Returns integer final total, and also stores it in #result
  def roll
    @result = 0
  end

  def explain_result
    return nil unless @result
  end

end # class Dice
