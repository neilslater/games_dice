# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  track_files 'lib/**/*.rb'
  add_filter { |source| !source.filename.start_with?(File.join(SimpleCov.root, 'lib/')) }
  coverage_dir 'coverage/ruby'
  use_merging false
  minimum_coverage line: 95, branch: 95
end
