// ext/games_dice/probabilities.c

#include "probabilities.h"

VALUE NewProbabilities = Qnil;

static ProbabilityList *create_probability_list() {
  ProbabilityList *pl;
  pl = malloc (sizeof(ProbabilityList));
  if ( pl == NULL ) {
    rb_raise(rb_eRuntimeError, "Could not allocate memory for NewProbabilities");
  }
  pl->probs = NULL;
  pl->slots = 0;
  pl->offset = 0;
  return pl;
}

static void destroy_probability_list( ProbabilityList *pl ) {
  free( pl->probs );
  free( pl );
  return;
}

static double *alloc_probs( ProbabilityList *pl, int slots ) {
  if ( slots < 1 || slots > 1000000 ) {
    rb_raise(rb_eArgError, "Bad number of probability slots");
  }
  pl->slots = slots;
  double *pr = malloc( slots * sizeof(double));
  if (pr == NULL) {
    rb_raise(rb_eRuntimeError, "Could not allocate memory for NewProbabilities");
  }
  pl->probs = pr;
  return pr;
}

static void init_probs_iv( ProbabilityList *pl, int slots, double iv ) {
  if ( iv < 0.0 || iv > 1.0 ) {
    rb_raise(rb_eArgError, "Bad single probability value");
  }
  double *pr = alloc_probs( pl, slots );
  int i;
  for(i=0; i<slots; i++) {
    pr[i] = iv;
  }
  return;
}

static VALUE pl_alloc(VALUE klass) {
  ProbabilityList *pl;
  VALUE obj;
  pl = create_probability_list();
  obj = Data_Wrap_Struct( klass, 0, destroy_probability_list, pl );
  return obj;
}

inline static ProbabilityList *get_probability_list( VALUE obj ) {
  ProbabilityList *pl;
  Data_Get_Struct( obj, ProbabilityList, pl );
  return pl;
}

static VALUE probabilities_initialize( VALUE self, VALUE arr, VALUE offset ) {
  int o = NUM2INT(offset);
  Check_Type( arr, T_ARRAY );
  int s = FIX2INT( rb_funcall( arr, rb_intern("count"), 0 ) );
  ProbabilityList *pl = get_probability_list( self );
  pl->offset = o;
  int i;
  double *pr = alloc_probs( pl, s );
  for(i=0; i<s; i++) {
    pr[i] = NUM2DBL( rb_ary_entry( arr, i ) );
  }
  return self;
}

VALUE probabilities_to_h( VALUE self ) {
  ProbabilityList *pl = get_probability_list( self );
  VALUE h = rb_hash_new();
  double *pr = pl->probs;
  int s = pl->slots;
  int o = pl->offset;
  int i;
  for(i=0; i<s; i++) {
    if ( pr[i] > 0.0 ) {
      rb_hash_aset( h, INT2FIX( o + i ), DBL2NUM( pr[i] ) );
    }
  }
  return h;
}

// Initialise whole class
void init_probabilities_class( VALUE ParentModule ) {
  NewProbabilities = rb_define_class_under( ParentModule, "NewProbabilities", rb_cObject );
  rb_define_alloc_func( NewProbabilities, pl_alloc );
  rb_define_method( NewProbabilities, "initialize", probabilities_initialize, 2 );
  rb_define_method( NewProbabilities, "to_h", probabilities_to_h, 0 );
  return;
}
