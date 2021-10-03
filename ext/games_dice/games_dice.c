// ext/games_dice/games_dice.c

#include <ruby.h>
#include "probabilities.h"

// To hold the module object
VALUE GamesDice = Qnil;

void Init_games_dice() {
  GamesDice = rb_define_module("GamesDice");
  init_probabilities_class();
}
