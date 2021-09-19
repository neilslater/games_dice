# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake/extensiontask'
require 'yard'

def can_compile_extensions
  return false if RUBY_DESCRIPTION =~ /jruby/

  true
end

desc 'GamesDice unit tests'
RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = 'spec/*_spec.rb'
  t.verbose = false
end

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
end

gemspec = Gem::Specification.load('games_dice.gemspec')
Rake::ExtensionTask.new do |ext|
  ext.name = 'games_dice'
  ext.source_pattern = '*.{c,h}'
  ext.ext_dir = 'ext/games_dice'
  ext.lib_dir = 'lib/games_dice'
  ext.gem_spec = gemspec
end

task :delete_compiled_ext do |_t|
  `rm lib/games_dice/games_dice.*`
end

task pure_test: %i[delete_compiled_ext test]

if can_compile_extensions
  task default: %i[compile test]
else
  task default: [:test]
end
