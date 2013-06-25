require "bundler/gem_tasks"
require "rspec/core/rake_task"
require 'rake/extensiontask'
require "yard"

desc "GamesDice unit tests"
RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = "spec/*_spec.rb"
  t.verbose = false
end

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
end

gemspec = Gem::Specification.load('games_dice.gemspec')
Rake::ExtensionTask.new do |ext|
  ext.name = 'games_dice'
  ext.ext_dir = 'ext/games_dice'
  ext.lib_dir = 'lib/games_dice'
  ext.gem_spec = gemspec
end

task :default => [:compile, :test]
