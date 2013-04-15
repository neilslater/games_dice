# utility class for calculating with probabilities for reuslts from GamesDice objects
class GamesDice::Probabilities
  # prob_hash is a Hash with each key as an Integer, and the associated value being the probability
  # of getting that value. It is not validated. Avoid using the default constructor if
  # one of the factory methods or calculation methods already does what you need.
  def initialize( prob_hash = { 0 => 1.0 } )
    # This should *probably* be validated in future
    @ph = prob_hash
  end

  # the Hash representation of probabilities. TODO: Hide this from public interface, but make it available
  # to factory methods
  attr_reader :ph

  # a clone of probability data (as provided to constructor), safe to pass to methods that modify in place
  def to_h
    @ph.clone
  end

  def min
    (@minmax ||= @ph.keys.minmax )[0]
  end

  def max
    (@minmax ||= @ph.keys.minmax )[1]
  end

  # returns mean expected value as a Float
  def expected
    @expected ||= @ph.inject(0.0) { |accumulate,p| accumulate + p[0] * p[1] }
  end

  # returns Float probability fram Range (0.0..1.0) that a value chosen from the distribution will
  # be equal to target integer
  def p_eql target
    @ph[ Integer(target) ] || 0.0
  end

  # returns Float probability fram Range (0.0..1.0) that a value chosen from the distribution will
  # be a number greater than target integer
  def p_gt target
    p_ge( Integer(target) + 1 )
  end

  # returns Float probability fram Range (0.0..1.0) that a value chosen from the distribution will
  # be a number greater than or equal to target integer
  def p_ge target
    target = Integer(target)
    return @prob_ge[target] if @prob_ge && @prob_ge[target]
    @prob_ge = {} unless @prob_ge

    return 1.0 if target <= min
    return 0.0 if target > max
    @prob_ge[target] = @ph.select {|k,v| target <= k}.inject(0.0) {|so_far,pv| so_far + pv[1] }
  end

  # returns probability than a roll will produce a number less than or equal to target integer
  def p_le target
    target = Integer(target)
    return @prob_le[target] if @prob_le && @prob_le[target]
    @prob_le = {} unless @prob_le

    return 1.0 if target >= max
    return 0.0 if target < min
    @prob_le[target] = @ph.select {|k,v| target >= k}.inject(0.0) {|so_far,pv| so_far + pv[1] }
  end

  # returns probability than a roll will produce a number less than target integer
  def p_lt target
    p_le( Integer(target) - 1 )
  end

  # constructor returns probability distrubution for a simple fair die
  def self.for_fair_die sides
    sides = Integer(sides)
    raise ArgumentError, "sides must be at least 1" unless sides > 0
    h = {}
    p = 1.0/sides
    (1..sides).each { |x| h[x] = p }
    GamesDice::Probabilities.new( h )
  end

  # adding two probability distributions calculates a new distribution, representing what would
  # happen if you created a random number using the sum of numbers from both distributions
  def self.add_distributions pd_a, pd_b
    h = {}
    pd_a.ph.each do |ka,pa|
      pd_b.ph.each do |kb,pb|
        kc = ka + kb
        pc = pa * pb
        h[kc] = h[kc] ? h[kc] + pc : pc
      end
    end
    GamesDice::Probabilities.new( h )
  end

end # class Dice
