# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'rspec/core/rake_task'
require 'rake/extensiontask'
require 'shellwords'
require 'yard'

desc 'GamesDice unit tests'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
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

task default: %i[compile spec]

rebuild_and_test_native = lambda do |mode, test: true|
  tasks = %w[clobber compile]
  tasks << 'spec' if test

  sh(
    { 'GAMES_DICE_NATIVE_MODE' => mode },
    RbConfig.ruby,
    '-S',
    'bundle',
    'exec',
    'rake',
    *tasks
  )
end

# Native quality orchestration is kept together so each task shares the same rebuild contract.
namespace :c do
  desc 'Compile the C extension with strict warnings'
  task :lint do
    rebuild_and_test_native.call('lint', test: false)
  end

  desc 'Measure C coverage using the full Ruby spec suite'
  task :coverage do
    cc = RbConfig::CONFIG.fetch('CC')
    compiler_version = Open3.capture2e(*Shellwords.split(cc), '--version').first

    unless compiler_version.match?(/gcc/i) && !compiler_version.match?(/clang/i)
      abort "c:coverage requires a GCC Ruby build (current compiler: #{cc})"
    end

    abort 'c:coverage requires gcovr on PATH' unless system('gcovr', '--version', out: File::NULL)

    rebuild_and_test_native.call('coverage')

    FileUtils.mkdir_p('coverage/c')
    sh(
      'gcovr',
      '--root', '.',
      '--filter', 'ext/games_dice/',
      '--html-details', 'coverage/c/index.html',
      '--xml', 'coverage/c/cobertura.xml',
      '--txt', 'coverage/c/summary.txt',
      '--print-summary'
    )
  end

  desc 'Run the Ruby specs with ASan and UBSan'
  task :sanitize do
    abort 'c:sanitize requires Linux' unless RUBY_PLATFORM.include?('linux')

    cc = RbConfig::CONFIG.fetch('CC')
    compiler_version = Open3.capture2e(*Shellwords.split(cc), '--version').first

    unless compiler_version.match?(/gcc/i) && !compiler_version.match?(/clang/i)
      abort "c:sanitize requires a GCC Ruby build (current compiler: #{cc})"
    end

    libasan = Open3.capture2e(*Shellwords.split(cc), '-print-file-name=libasan.so').first.strip
    abort 'c:sanitize could not locate the GCC ASan runtime' if libasan.empty? || libasan == 'libasan.so'

    rebuild_and_test_native.call('sanitize', test: false)

    sh(
      { 'ASAN_OPTIONS' => 'detect_leaks=0', 'LD_PRELOAD' => libasan },
      RbConfig.ruby,
      '-S',
      'bundle',
      'exec',
      'rake',
      'spec'
    )
  end
end
