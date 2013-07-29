# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'games_dice/version'

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
  gem.add_development_dependency "coveralls", ">= 0.6.7"
  gem.add_development_dependency "json", ">= 1.7.7"
  gem.add_development_dependency "rake-compiler", ">= 0.8.3"

  # Red Carpet renders README.md, and is optional even when developing the gem.
  # However, it has a C extension, and v3.0.0 is does not compile for 1.8.7. This only affects the gem build process, so
  # is only really used in environments like Travis, and is safe to wrap like this in the gemspec.
  if RUBY_DESCRIPTION !~ /jruby/
    if RUBY_VERSION >= "1.9.0"
      gem.add_development_dependency "redcarpet", ">=2.3.0"
    else
      gem.add_development_dependency "redcarpet", ">=2.3.0", "<3.0.0"
    end
  end

  gem.add_dependency "parslet", ">= 1.5.0"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.extensions    = gem.files.grep(%r{/extconf\.rb$})
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
