require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "yard"

task :default => [:test]

desc "GamesDice unit tests"
RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = "spec/*_spec.rb"
  t.verbose = false
end

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
end
