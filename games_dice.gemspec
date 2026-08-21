# frozen_string_literal: true

require 'English'
lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'games_dice/version'

Gem::Specification.new do |gem|
  gem.name          = 'games_dice'
  gem.version       = GamesDice::VERSION
  gem.authors       = ['Neil Slater']
  gem.email         = ['slobo777@gmail.com']
  gem.description   = <<~GEMDESC
    A library for simulating dice. Use it to construct dice-rolling systems used in role-playing and board games.
  GEMDESC
  gem.summary = <<~GEMSUMM
    Simulates and explains dice rolls from simple "1d6" to complex "roll 7 ten-sided dice, take best 3,
    results of 10 roll again and add on".
  GEMSUMM
  gem.homepage      = 'https://github.com/neilslater/games_dice'
  gem.license       = 'MIT'

  gem.required_ruby_version = '>= 3.3.0'

  gem.add_dependency 'parslet', '~> 2.0'

  gem.files         = `git ls-files -z`.split("\0").select { |file| File.file?(file) && file != 'Gemfile.lock' }
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.extensions    = gem.files.grep(%r{/extconf\.rb$})
  gem.require_paths = ['lib']
  gem.metadata['rubygems_mfa_required'] = 'true'
end
