# frozen_string_literal: true

module GamesDice
  # Reasons for making a reroll, and text explanation symbols for them
  REROLL_TYPES = {
    basic: ',',
    reroll_add: '+',
    reroll_subtract: '-',
    reroll_replace: '|',
    reroll_use_best: '/',
    reroll_use_worst: '\\'
    # These are not yet implemented:
    # :reroll_new_die => '*',
    # :reroll_new_keeper => '*',
  }.freeze
end
