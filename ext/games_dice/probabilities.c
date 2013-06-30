// ext/games_dice/probabilities.c

#include <stdio.h>
#include "probabilities.h"

VALUE NewProbabilities = Qnil;

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  General utils
//

static inline int max( int *a, int n ) {
  int m = -1000000000;
  int i;
  for ( i=0; i < n; i++ ) {
    m = a[i] > m ? a[i] : m;
  }
  return m;
}

static inline int min( int *a, int n ) {
  int m = 1000000000;
  int i;
  for ( i=0; i < n; i++ ) {
    m = a[i] < m ? a[i] : m;
  }
  return m;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Probability List basics - create, delete, copy
//

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
  // TODO: Should this be a NALLOC?
  double *pr = malloc( slots * sizeof(double));
  if (pr == NULL) {
    rb_raise(rb_eRuntimeError, "Could not allocate memory for NewProbabilities");
  }
  pl->probs = pr;
  return pr;
}

static double *alloc_probs_iv( ProbabilityList *pl, int slots, double iv ) {
  if ( iv < 0.0 || iv > 1.0 ) {
    rb_raise(rb_eArgError, "Bad single probability value");
  }
  double *pr = alloc_probs( pl, slots );
  int i;
  for(i=0; i<slots; i++) {
    pr[i] = iv;
  }
  return pr;
}

static ProbabilityList *copy_probability_list( ProbabilityList *orig ) {
  ProbabilityList *pl = create_probability_list();
  double *pr = alloc_probs( pl, orig->slots );
  pl->offset = orig->offset;
  memcpy( pr, orig->probs, orig->slots * sizeof(double) );
  return pl;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Probability List core "native" methods
//

static inline int pl_min( ProbabilityList *pl ) {
  return pl->offset;
}

static inline int pl_max( ProbabilityList *pl ) {
  return pl->offset + pl->slots - 1;
}

static ProbabilityList *pl_add_distributions( ProbabilityList *pl_a, ProbabilityList *pl_b ) {
  int s = pl_a->slots + pl_b->slots;
  int o = pl_a->offset + pl_b->offset;
  int i,j;

  ProbabilityList *pl = create_probability_list();
  pl->offset = o;
  double *pr = alloc_probs_iv( pl, s, 0.0 );
  for ( i=0; i < pl_a->slots; i++ ) { for ( j=0; j < pl_b->slots; j++ ) {
    pr[ i + j ] += (pl_a->probs)[i] * (pl_b->probs)[j];
  } }
  return pl;
}

static ProbabilityList *pl_add_distributions_mult( int mul_a, ProbabilityList *pl_a, int mul_b, ProbabilityList *pl_b ) {
  int pts[4] = {
    mul_a * pl_min( pl_a ) + mul_b * pl_min( pl_b ),
    mul_a * pl_max( pl_a ) + mul_b * pl_min( pl_b ),
    mul_a * pl_min( pl_a ) + mul_b * pl_max( pl_b ),
    mul_a * pl_max( pl_a ) + mul_b * pl_max( pl_b ) };

  int combined_min = min( pts, 4 );
  int combined_max = max( pts, 4 );
  int s =  1 + combined_max - combined_min;

  ProbabilityList *pl = create_probability_list();
  pl->offset = combined_min;
  double *pr = alloc_probs_iv( pl, s, 0.0 );
  int i,j;
  for ( i=0; i < pl_a->slots; i++ ) { for ( j=0; j < pl_b->slots; j++ ) {
    int k = mul_a * (i + pl_a->offset) + mul_b * (j + pl_b->offset) - combined_min;
    pr[ i + j ] += (pl_a->probs)[i] * (pl_b->probs)[j];
  } }
  return pl;
}

static inline double pl_p_eql( ProbabilityList *pl, int target ) {
  int idx = target - pl->offset;
  if ( idx < 0 || idx >= pl->slots ) {
    return 0.0;
  }
  return (pl->probs)[idx];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Ruby integration
//

static inline VALUE pl_as_ruby_class( ProbabilityList *pl, VALUE klass ) {
  return Data_Wrap_Struct( klass, 0, destroy_probability_list, pl );
}

static VALUE pl_alloc(VALUE klass) {
  return pl_as_ruby_class( create_probability_list(), klass );
}

inline static ProbabilityList *get_probability_list( VALUE obj ) {
  ProbabilityList *pl;
  Data_Get_Struct( obj, ProbabilityList, pl );
  return pl;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Ruby class and instance methods for NewProbabilities
//

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

VALUE probabilities_min( VALUE self ) {
  return INT2NUM( pl_min(  get_probability_list( self ) ) );
}

VALUE probabilities_max( VALUE self ) {
  return INT2NUM( pl_max( get_probability_list( self ) ) );
}

VALUE probabilites_p_eql( VALUE self, VALUE target ) {
  return DBL2NUM( pl_p_eql( get_probability_list( self ), NUM2INT(target) ) );
}

VALUE probabilities_for_fair_die( VALUE self, VALUE sides ) {
  int s = NUM2INT( sides );
  if ( s < 1 ) {
    rb_raise( rb_eArgError, "Number of sides should be 1 or more" );
  }
  VALUE obj = pl_alloc( NewProbabilities );
  ProbabilityList *pl = get_probability_list( obj );
  pl->offset = 1;
  alloc_probs_iv( pl, s, 1.0/s );
  return obj;
}

VALUE probabilities_add_distributions( VALUE self, VALUE gdpa, VALUE gdpb ) {
  // TODO: Confirm types before progressing
  ProbabilityList *pl_a = get_probability_list( gdpa );
  ProbabilityList *pl_b = get_probability_list( gdpb );
  return pl_as_ruby_class( pl_add_distributions( pl_a, pl_b ), NewProbabilities );
}

VALUE probabilities_add_distributions_mult( VALUE self, VALUE m_a, VALUE gdpa, VALUE m_b, VALUE gdpb ) {
  // TODO: Confirm types before progressing
  int mul_a = NUM2INT( m_a );
  ProbabilityList *pl_a = get_probability_list( gdpa );
  int mul_b = NUM2INT( m_b );
  ProbabilityList *pl_b = get_probability_list( gdpb );
  return pl_as_ruby_class( pl_add_distributions_mult( mul_a, pl_a, mul_b, pl_b ), NewProbabilities );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Setup NewProbabilities
//

void init_probabilities_class( VALUE ParentModule ) {
  NewProbabilities = rb_define_class_under( ParentModule, "NewProbabilities", rb_cObject );
  rb_define_alloc_func( NewProbabilities, pl_alloc );
  rb_define_method( NewProbabilities, "initialize", probabilities_initialize, 2 );
  rb_define_method( NewProbabilities, "to_h", probabilities_to_h, 0 );
  rb_define_method( NewProbabilities, "min", probabilities_min, 0 );
  rb_define_method( NewProbabilities, "max", probabilities_max, 0 );
  rb_define_method( NewProbabilities, "p_eql", probabilites_p_eql, 1 );
  rb_define_singleton_method( NewProbabilities, "for_fair_die", probabilities_for_fair_die, 1 );
  rb_define_singleton_method( NewProbabilities, "add_distributions", probabilities_add_distributions, 2 );
  rb_define_singleton_method( NewProbabilities, "add_distributions_mult", probabilities_add_distributions_mult, 4 );
  return;
}
