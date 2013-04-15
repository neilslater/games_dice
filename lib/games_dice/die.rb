# basic die that rolls 1..N, typically with equal weighting for each value
#  d = Die.new(6)
#  d.roll # => Integer in range 1..6
#  d.result # => same Integer value as returned by d.roll
class GamesDice::Die
  # sides is e.g. 6 for traditional cubic die, or 20 for icosahedron.
  # It can take non-traditional values, such as 7, but must be at least 1.
  # prng is an object that has a rand(x) method. If provided, it will be called as
  # prng.rand(sides), and is expected to return an integer in range 0...sides
  def initialize( sides, prng=nil )
    @sides = Integer(sides)
    raise ArgumentError, "sides value #{sides} is too low, it must be 1 or greater" if @sides < 1
    raise ArgumentError, "prng does not support the rand() method" if prng && ! prng.respond_to?(:rand)
    @prng = prng
    @result = nil
  end

  # number of sides as set by #new
  attr_reader :sides

  # integer result of last call to #roll, nil if no call made yet
  attr_reader :result

  # minimum possible value
  def min
    1
  end

  # maximum possible value
  def max
    @sides
  end

  # returns a GamesDice::Probabilities object that models distribution of the die
  def probabilities
    return @probabilities if @probabilities
    @probabilities = GamesDice::Probabilities.for_fair_die( @sides )
  end

  # generates Integer between #min and #max, using rand()
  def roll
    if @prng
      @result = @prng.rand(@sides) + 1
    else
      @result = rand(@sides) + 1
    end
  end

  # always nil, available for compatibility with ComplexDie
  def rerolls
    nil
  end

  # always nil, available for compatibility with ComplexDie
  def maps
    nil
  end
end # class Die
