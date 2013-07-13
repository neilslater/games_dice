# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'games_dice/version'

def can_compile_extensions
  return false if RUBY_DESCRIPTION =~ /jruby/
  return true
end

Gem::Specification.new do |gem|
  gem.name          = "games_dice"
  gem.version       = GamesDice::VERSION
  gem.authors       = ["Neil Slater"]
  gem.email         = ["slobo777@gmail.com"]
  gem.description   = %q{A library for simulating dice. Use it to construct dice-rolling systems used in role-playing and board games.}
  gem.summary       = %q{Simulates and explains dice rolls from simple "1d6" to complex "roll 7 ten-sided dice, take best 3,
                        results of 10 roll again and add on".}
  gem.homepage      = "https://github.com/neilslater/games_dice"
  gem.license       = "MIT"

  gem.add_development_dependency "rspec", ">= 2.13.0"
  gem.add_development_dependency "rake", ">= 1.9.1"
  gem.add_development_dependency "yard", ">= 0.8.6"
  gem.add_development_dependency "rake-compiler"

  if RUBY_VERSION < "1.9.0"
    # Red Carpet v3.0.0 does not compile for 1.8.7
    gem.add_development_dependency "redcarpet", ">=2.3.0", "<3.0.0"
  else
    gem.add_development_dependency "redcarpet", ">=2.3.0"
  end

  gem.add_dependency "parslet", ">= 1.5.0"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }

  if can_compile_extensions
    gem.extensions    = gem.files.grep(%r{/extconf\.rb$})
  end

  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
