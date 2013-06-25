// ext/games_dice/probabilities.c

#include "probabilities.h"

VALUE NewProbabilities = Qnil;

VALUE probabilities_init( VALUE self, VALUE arr, VALUE offset ) {
  int o = NUM2INT(offset);
  Check_Type( arr, T_ARRAY );
  return self;
}

VALUE probabilities_to_h( VALUE self ) {
  return self;
}

// Initialise whole class
void init_probabilities_class( VALUE ParentModule ) {
  NewProbabilities = rb_define_class_under( ParentModule, "NewProbabilities", rb_cObject );
  rb_define_method( NewProbabilities, "initialize", probabilities_init, 2 );
  rb_define_method( NewProbabilities, "to_h", probabilities_to_h, 0 );
  return;
}
