# frozen_string_literal: true

module GamesDice
  # This class models probability distributions for dice systems.
  #
  # An object of this class represents a single distribution, which might be the result of a complex
  # combination of dice.
  #
  # @example Distribution for a six-sided die
  #  probs = GamesDice::Probabilities.for_fair_die( 6 )
  #  probs.min # => 1
  #  probs.max # => 6
  #  probs.expected # => 3.5
  #  probs.p_ge( 4 ) # => 0.5
  #
  # @example Adding two distributions
  #  pd6 = GamesDice::Probabilities.for_fair_die( 6 )
  #  probs = GamesDice::Probabilities.add_distributions( pd6, pd6 )
  #  probs.min # => 2
  #  probs.max # => 12
  #  probs.expected # => 7.0
  #  probs.p_ge( 10 ) # => 0.16666666666666669
  #
  class Probabilities
    # @!visibility private
    # Adds support for Marshal, via to_h and from_h methods
    def marshal_dump
      to_h
    end

    # @!visibility private
    def self._load(buf)
      # Use of Marshal for general-purpose object serialisation is discouraged. However, this class does support
      # it for backwards-compatibility.
      # rubocop:disable Security/MarshalLoad
      h = Marshal.load buf
      # rubocop:enable Security/MarshalLoad
      from_h h
    end
  end
end
