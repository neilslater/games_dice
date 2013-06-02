# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'games_dice/version'

Gem::Specification.new do |gem|
  gem.name          = "games_dice"
  gem.version       = GamesDice::VERSION
  gem.authors       = ["Neil Slater"]
  gem.email         = ["slobo777@gmail.com"]
  gem.description   = %q{A simulated-dice library, with flexible rules that allow dice systems from
                        many board and roleplay games to be built, run and reported.}
  gem.summary       = %q{Simulates and explains dice rolls from simple "1d6" to complex "roll 7 ten-sided dice, take best 3,
                        results of 10 roll again and add on".}
  gem.homepage      = "https://github.com/neilslater/games_dice"

  gem.add_development_dependency "rspec", ">= 2.13.0"
  gem.add_development_dependency "rake", ">= 1.9.1"
  gem.add_development_dependency "yard", ">= 0.8.6"
  gem.add_development_dependency "redcarpet", ">=2.3.0"

  gem.add_dependency "parslet", ">= 1.5.0"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
