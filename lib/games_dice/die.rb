# A basic die that rolls 1..#sides, with equal weighting for each value.
#
# @example Create a 6-sided die, and roll it
#  d = GamesDice::Die.new( 6 )
#  d.roll # => Integer in range 1..6
#  d.result # => same Integer value as just returned by d.roll
#
# @example Create a 10-sided die, that rolls using a monkey-patch to SecureRandom
#  module SecureRandom
#    def self.rand n
#      random_number( n )
#    end
#  end
#  d = GamesDice::Die.new( 10, SecureRandom )
#  d.roll # => (secure) Integer in range 1..10
#  d.result # => same Integer value as just returned by d.roll

class GamesDice::Die

  # Creates new instance of GamesDice::Die
  # @param [Integer] sides the number of sides
  # @param [#rand] prng random number generator, GamesDice::Die will use Ruby's built-in #rand() by default
  # @return [GamesDice::Die]
  def initialize( sides, prng=nil )
    @sides = Integer(sides)
    raise ArgumentError, "sides value #{sides} is too low, it must be 1 or greater" if @sides < 1
    raise ArgumentError, "prng does not support the rand() method" if prng && ! prng.respond_to?(:rand)
    @prng = prng
    @result = nil
  end

  # @return [Integer] number of sides on simulated die
  attr_reader :sides

  # @return [Integer] result of last call to #roll, nil if no call made yet
  attr_reader :result

  # @return [Object] random number generator as supplied to constructor, may be nil
  attr_reader :prng

  # @!attribute [r] min
  # @return [Integer] minimum possible result from a call to #roll
  def min
    1
  end

  # @!attribute [r] max
  # @return [Integer] maximum possible result from a call to #roll
  def max
    @sides
  end

  # Calculates probability distribution for this die.
  # @return [GamesDice::Probabilities] probability distribution of the die
  def probabilities
    return @probabilities if @probabilities
    @probabilities = GamesDice::Probabilities.for_fair_die( @sides )
  end

  # Simulates rolling the die
  # @return [Integer] selected value between 1 and #sides inclusive
  def roll
    if @prng
      @result = @prng.rand(@sides) + 1
    else
      @result = rand(@sides) + 1
    end
  end

  # @!attribute [r] rerolls
  # Rules for when to re-roll this die.
  # @return [nil] always nil, available for interface equivalence with GamesDice::ComplexDie
  def rerolls
    nil
  end

  # @!attribute [r] maps
  # Rules for when to map return value of this die.
  # @return [nil] always nil, available for interface equivalence with GamesDice::ComplexDie
  def maps
    nil
  end
end # class GamesDice::Die
