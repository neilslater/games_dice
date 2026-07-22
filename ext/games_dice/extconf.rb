# frozen_string_literal: true

# ext/games_dice/extconf.rb

require 'mkmf'
require 'rbconfig'

# mkmf exposes compiler and linker flags through these globals.
# rubocop:disable Style/GlobalVars
case ENV.fetch('GAMES_DICE_NATIVE_MODE', 'release')
when 'release'
  # Use Ruby's normal extension build flags.
when 'lint'
  $CFLAGS << ' -std=gnu2x -O0 -g'
  $CFLAGS << ' -Wall -Wextra -Wpedantic -Wformat=2 -Werror'

  cc = RbConfig::CONFIG.fetch('CC')
  host_os = RbConfig::CONFIG.fetch('host_os')
  if cc.include?('clang') || host_os.include?('darwin')
    # Ruby callback signatures legitimately leave some parameters unused, and
    # Ruby 4 headers use standard attributes that Clang treats as C23 syntax.
    $CFLAGS << ' -Wno-strict-prototypes -Wno-unused-parameter -Wno-c23-extensions'
  end
when 'coverage'
  $CFLAGS << ' -O0 -g --coverage'
  $LDFLAGS << ' --coverage'
when 'sanitize'
  $CFLAGS << ' -O1 -g -fsanitize=address,undefined'
  $CFLAGS << ' -fno-omit-frame-pointer'
  $LDFLAGS << ' -fsanitize=address,undefined'
else
  abort "Unknown GAMES_DICE_NATIVE_MODE: #{ENV.fetch('GAMES_DICE_NATIVE_MODE', nil)}"
end
# rubocop:enable Style/GlobalVars

create_makefile('games_dice/games_dice')
