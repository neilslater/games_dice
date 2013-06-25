// ext/games_dice/games_dice.c

#include <ruby.h>
#include "probabilities.h"

// To hold the module object
VALUE GamesDice = Qnil;

// Declarations for bindings are here and not in header, as no need to share them with other C code.
void Init_games_dice();

// Setup the module and methods
void Init_games_dice() {
  GamesDice = rb_define_module("GamesDice");
  init_probabilities_class( GamesDice );
}
