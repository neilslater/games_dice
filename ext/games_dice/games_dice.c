// ext/games_dice/games_dice.c

#include <ruby.h>

// To hold the module object
VALUE GamesDice = Qnil;

// Declarations for bindings are here and not in header, as no need to share them with other C code.
void Init_games_dice();
VALUE method_ext_test(VALUE self);

// Setup the module and methods
void Init_games_dice() {
  GamesDice = rb_define_module("GamesDice");
  rb_define_singleton_method(GamesDice, "ext_test", method_ext_test, 0);
}

// Returns magic number 9093 as a test
VALUE method_ext_test(VALUE self) {
  return INT2NUM( 9093 );
}
