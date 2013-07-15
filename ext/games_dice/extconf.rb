# ext/games_dice/extconf.rb
if RUBY_DESCRIPTION =~ /jruby/
  mfile = open("Makefile", "wb")
  mfile.puts '.PHONY: install'
  mfile.puts 'install:'
  mfile.puts "\t" + '@echo "Extensions not installed, falling back to pure Ruby version."'
  mfile.close
else
  require 'mkmf'
  create_makefile( 'games_dice/games_dice' )
end
