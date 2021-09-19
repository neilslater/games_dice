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
  gem.description   = 'A library for simulating dice. Use it to construct dice-rolling systems used in role-playing and board games.'
  gem.summary       = 'Simulates and explains dice rolls from simple "1d6" to complex "roll 7 ten-sided dice, take best 3,
                        results of 10 roll again and add on".'
  gem.homepage      = 'https://github.com/neilslater/games_dice'
  gem.license       = 'MIT'

  gem.add_development_dependency 'coveralls', '>= 0.6.7'
  gem.add_development_dependency 'json', '>= 1.7.7'
  gem.add_development_dependency 'rake', '>= 1.9.1'
  gem.add_development_dependency 'rake-compiler', '>= 0.8.3'
  gem.add_development_dependency 'rspec', '>= 2.13.0'
  gem.add_development_dependency 'rubocop', '>= 1.2.1'
  gem.add_development_dependency 'yard', '>= 0.8.6'

  # Red Carpet renders README.md, and is optional even when developing the gem.
  # However, it has a C extension, which will not work in JRuby. This only affects the gem build process, so
  # is only really used in environments like Travis, and is safe to wrap like this in the gemspec.
  gem.add_development_dependency 'redcarpet', '>=3.5.1' if RUBY_DESCRIPTION !~ /jruby/

  gem.add_dependency 'parslet', '>= 1.5.0'

  gem.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.extensions    = gem.files.grep(%r{/extconf\.rb$})
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']
end
