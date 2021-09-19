# frozen_string_literal: true

# ext/games_dice/extconf.rb
can_compile_extensions = false
want_extensions = true

begin
  require 'mkmf'
  can_compile_extensions = true
rescue Exception
  # This will appear only in verbose mode.
  warn "Could not require 'mkmf'. Not fatal: The extensions are optional."
end

if can_compile_extensions && want_extensions
  create_makefile('games_dice/games_dice')

else
  # Create a dummy Makefile, to satisfy Gem::Installer#install
  mfile = open('Makefile', 'wb')
  mfile.puts '.PHONY: install'
  mfile.puts 'install:'
  mfile.puts "\t@echo \"Extensions not installed, falling back to pure Ruby version.\""
  mfile.close

end
