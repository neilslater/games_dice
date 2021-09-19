# frozen_string_literal: true

module GamesDice
  class Probabilities
    # @!visibility private
    # Adds support for Marshal, via to_h and from_h methods
    def _dump(*_ignored)
      Marshal.dump to_h
    end

    # @!visibility private
    def self._load(buf)
      h = Marshal.load buf
      from_h h
    end
  end
end
