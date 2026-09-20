# frozen_string_literal: true

require 'yard'

# Match the Ruby source and visibility boundary used by the documentation task.
# Stats reports omissions but does not fail on them, so check the parsed objects too.
stats = YARD::CLI::Stats.new
stats.run('--list-undoc', '--fail-on-warning', '--no-cache', '--no-save', 'lib/**/*.rb')
abort 'Documentation check found no objects' if stats.all_objects.empty?
abort 'Documentation check found undocumented objects' if stats.all_objects.any? { |object| object.docstring.blank? }
