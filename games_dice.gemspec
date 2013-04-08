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
  gem.summary       = %q{Simulates and explains dice rolls from a variety of game systems.}
  gem.homepage      = ""

  gem.add_development_dependency "rspec"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
