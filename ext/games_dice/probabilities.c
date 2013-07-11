// ext/games_dice/probabilities.c

#include "probabilities.h"

// Ruby 1.8.7 compatibility patch
#ifndef DBL2NUM
#define DBL2NUM( dbl_val ) rb_float_new( dbl_val )
#endif

// Force inclusion of hash declarations (only MRI includes by default)
#ifdef HAVE_RUBY_ST_H
#include "ruby/st.h"
#else
#include "st.h"
#endif

VALUE Probabilities = Qnil;

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
//  Quick factorials, that fit into unsigned longs . . . the size of this structure sets the
//  maximum possible n in repeat_n_sum_k calculations
//

// There is no point calculating these, a cache of them is just fine.
static double nfact[171] = {
  1.0, 1.0, 2.0, 6.0,
  24.0, 120.0, 720.0, 5040.0,
  40320.0, 362880.0, 3628800.0, 39916800.0,
  479001600.0, 6227020800.0, 87178291200.0, 1307674368000.0,
  20922789888000.0, 355687428096000.0, 6402373705728000.0, 121645100408832000.0,
  2432902008176640000.0, 51090942171709440000.0, 1124000727777607700000.0, 25852016738884980000000.0,
  620448401733239400000000.0, 15511210043330986000000000.0, 403291461126605650000000000.0, 10888869450418352000000000000.0,
  304888344611713870000000000000.0, 8841761993739702000000000000000.0, 2.6525285981219107e+32, 8.222838654177922e+33,
  2.631308369336935e+35, 8.683317618811886e+36, 2.9523279903960416e+38, 1.0333147966386145e+40,
  3.7199332678990125e+41, 1.3763753091226346e+43, 5.230226174666011e+44, 2.0397882081197444e+46,
  8.159152832478977e+47, 3.345252661316381e+49, 1.40500611775288e+51, 6.041526306337383e+52,
  2.658271574788449e+54, 1.1962222086548019e+56, 5.502622159812089e+57, 2.5862324151116818e+59,
  1.2413915592536073e+61, 6.082818640342675e+62, 3.0414093201713376e+64, 1.5511187532873822e+66,
  8.065817517094388e+67, 4.2748832840600255e+69, 2.308436973392414e+71, 1.2696403353658276e+73,
  7.109985878048635e+74, 4.0526919504877214e+76, 2.3505613312828785e+78, 1.3868311854568984e+80,
  8.32098711274139e+81, 5.075802138772248e+83, 3.146997326038794e+85, 1.98260831540444e+87,
  1.2688693218588417e+89, 8.247650592082472e+90, 5.443449390774431e+92, 3.647111091818868e+94,
  2.4800355424368305e+96, 1.711224524281413e+98, 1.1978571669969892e+100, 8.504785885678623e+101,
  6.1234458376886085e+103, 4.4701154615126844e+105, 3.307885441519386e+107, 2.48091408113954e+109,
  1.8854947016660504e+111, 1.4518309202828587e+113, 1.1324281178206297e+115, 8.946182130782976e+116,
  7.156945704626381e+118, 5.797126020747368e+120, 4.753643337012842e+122, 3.945523969720659e+124,
  3.314240134565353e+126, 2.81710411438055e+128, 2.4227095383672734e+130, 2.107757298379528e+132,
  1.8548264225739844e+134, 1.650795516090846e+136, 1.4857159644817615e+138, 1.352001527678403e+140,
  1.2438414054641308e+142, 1.1567725070816416e+144, 1.087366156656743e+146, 1.032997848823906e+148,
  9.916779348709496e+149, 9.619275968248212e+151, 9.426890448883248e+153, 9.332621544394415e+155,
  9.332621544394415e+157, 9.42594775983836e+159, 9.614466715035127e+161, 9.90290071648618e+163,
  1.0299016745145628e+166, 1.081396758240291e+168, 1.1462805637347084e+170, 1.226520203196138e+172,
  1.324641819451829e+174, 1.4438595832024937e+176, 1.588245541522743e+178, 1.7629525510902446e+180,
  1.974506857221074e+182, 2.2311927486598138e+184, 2.5435597334721877e+186, 2.925093693493016e+188,
  3.393108684451898e+190, 3.969937160808721e+192, 4.684525849754291e+194, 5.574585761207606e+196,
  6.689502913449127e+198, 8.094298525273444e+200, 9.875044200833601e+202, 1.214630436702533e+205,
  1.506141741511141e+207, 1.882677176888926e+209, 2.372173242880047e+211, 3.0126600184576594e+213,
  3.856204823625804e+215, 4.974504222477287e+217, 6.466855489220474e+219, 8.47158069087882e+221,
  1.1182486511960043e+224, 1.4872707060906857e+226, 1.9929427461615188e+228, 2.6904727073180504e+230,
  3.659042881952549e+232, 5.012888748274992e+234, 6.917786472619489e+236, 9.615723196941089e+238,
  1.3462012475717526e+241, 1.898143759076171e+243, 2.695364137888163e+245, 3.854370717180073e+247,
  5.5502938327393044e+249, 8.047926057471992e+251, 1.1749972043909107e+254, 1.727245890454639e+256,
  2.5563239178728654e+258, 3.80892263763057e+260, 5.713383956445855e+262, 8.62720977423324e+264,
  1.3113358856834524e+267, 2.0063439050956823e+269, 3.0897696138473508e+271, 4.789142901463394e+273,
  7.471062926282894e+275, 1.1729568794264145e+278, 1.853271869493735e+280, 2.9467022724950384e+282,
  4.7147236359920616e+284, 7.590705053947219e+286, 1.2296942187394494e+289, 2.0044015765453026e+291,
  3.287218585534296e+293, 5.423910666131589e+295, 9.003691705778438e+297, 1.503616514864999e+300,
  2.5260757449731984e+302, 4.269068009004705e+304, 7.257415615307999e+306 };

static double num_arrangements( int *args, int nargs ) {
  int sum = 0;
  double div_by = 1.0;
  int i;
  for ( i = 0; i < nargs; i++ ) {
    sum += args[i];
    if ( sum > 170 ) {
      rb_raise( rb_eRuntimeError, "Too many dice to calculate numbers of arrangements" );
    }
    div_by *= nfact[ args[i] ];
  }
  return nfact[ sum ] / div_by;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Probability List basics - create, delete, copy
//

static ProbabilityList *create_probability_list() {
  ProbabilityList *pl;
  pl = malloc (sizeof(ProbabilityList));
  if ( pl == NULL ) {
    rb_raise(rb_eRuntimeError, "Could not allocate memory for Probabilities");
  }
  pl->probs = NULL;
  pl->cumulative = NULL;
  pl->slots = 0;
  pl->offset = 0;
  return pl;
}

static void destroy_probability_list( ProbabilityList *pl ) {
  xfree( pl->cumulative );
  xfree( pl->probs );
  xfree( pl );
  return;
}

static double *alloc_probs( ProbabilityList *pl, int slots ) {
  if ( slots < 1 || slots > 1000000 ) {
    rb_raise(rb_eArgError, "Bad number of probability slots");
  }
  pl->slots = slots;

  double *pr = ALLOC_N( double, slots );
  pl->probs = pr;

  pl->cumulative = ALLOC_N( double, slots );

  return pr;
}

static double calc_cumulative( ProbabilityList *pl ) {
  double *c = pl->cumulative;
  double *pr = pl->probs;
  int i;
  double t = 0.0;
  for(i=0; i < pl->slots; i++) {
    t += pr[i];
    c[i] = t;
  }
  return t;
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
  calc_cumulative( pl );
  return pr;
}

static ProbabilityList *copy_probability_list( ProbabilityList *orig ) {
  ProbabilityList *pl = create_probability_list();
  double *pr = alloc_probs( pl, orig->slots );
  pl->offset = orig->offset;
  memcpy( pr, orig->probs, orig->slots * sizeof(double) );
  memcpy( pl->cumulative, orig->cumulative, orig->slots * sizeof(double) );
  return pl;
}

static inline ProbabilityList *new_basic_pl( int nslots, double iv, int o ) {
  ProbabilityList *pl = create_probability_list();
  alloc_probs_iv( pl, nslots, iv );
  pl->offset = o;
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
  int s = pl_a->slots + pl_b->slots - 1;
  int o = pl_a->offset + pl_b->offset;
  int i,j;

  ProbabilityList *pl = create_probability_list();
  pl->offset = o;
  double *pr = alloc_probs_iv( pl, s, 0.0 );
  for ( i=0; i < pl_a->slots; i++ ) { for ( j=0; j < pl_b->slots; j++ ) {
    pr[ i + j ] += (pl_a->probs)[i] * (pl_b->probs)[j];
  } }
  calc_cumulative( pl );
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
    pr[ k ] += (pl_a->probs)[i] * (pl_b->probs)[j];
  } }
  calc_cumulative( pl );
  return pl;
}

static inline double pl_p_eql( ProbabilityList *pl, int target ) {
  int idx = target - pl->offset;
  if ( idx < 0 || idx >= pl->slots ) {
    return 0.0;
  }
  return (pl->probs)[idx];
}

static inline double pl_p_gt( ProbabilityList *pl, int target ) {
  return 1.0 - pl_p_le( pl, target );
}

static inline double pl_p_lt( ProbabilityList *pl, int target ) {
  return pl_p_le( pl, target - 1 );
}

static inline double pl_p_le( ProbabilityList *pl, int target ) {
  int idx = target - pl->offset;
  if ( idx < 0 ) {
    return 0.0;
  }
  if ( idx >= pl->slots - 1 ) {
    return 1.0;
  }
  return (pl->cumulative)[idx];
}

static inline double pl_p_ge( ProbabilityList *pl, int target ) {
  return 1.0 - pl_p_le( pl, target - 1 );
}

static inline double pl_expected( ProbabilityList *pl ) {
  double t = 0.0;
  int o = pl->offset;
  int s = pl->slots;
  double *pr = pl->probs;
  int i;
  for ( i = 0; i < s ; i++ ) {
    t += ( i + o ) * pr[i];
  }
  return t;
}

static ProbabilityList *pl_given_ge( ProbabilityList *pl, int target ) {
  int m = pl_min( pl );
  if ( m > target ) {
    target = m;
  }
  double p = pl_p_ge( pl, target );
  if ( p <= 0.0 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate given probabilities, divide by zero" );
  }
  double mult = 1.0/p;
  int s = pl->slots + pl->offset - target;
  double *pr = pl->probs;

  ProbabilityList *new_pl = create_probability_list();
  new_pl->offset = target;
  double *new_pr = alloc_probs( new_pl, s );
  int o = target - pl->offset;
  int i;
  for ( i = 0; i < s; i++ ) {
    new_pr[i] = pr[o + i] * mult;
  }
  calc_cumulative( new_pl );
  return new_pl;
}

static ProbabilityList *pl_given_le( ProbabilityList *pl, int target ) {
  int m = pl_max( pl );
  if ( m < target ) {
    target = m;
  }
  double p = pl_p_le( pl, target );
  if ( p <= 0.0 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate given probabilities, divide by zero" );
  }
  double mult = 1.0/p;
  int s = target - pl->offset + 1;
  double *pr = pl->probs;

  ProbabilityList *new_pl = create_probability_list();
  new_pl->offset = pl->offset;
  double *new_pr = alloc_probs( new_pl, s );
  int i;
  for ( i = 0; i < s; i++ ) {
    new_pr[i] = pr[i] * mult;
  }
  calc_cumulative( new_pl );
  return new_pl;
}

static ProbabilityList *pl_repeat_sum( ProbabilityList *pl, int n ) {
  if ( n < 1 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate repeat_sum when n < 1" );
  }
  if ( n * pl->slots - n >  1000000 ) {
    rb_raise( rb_eRuntimeError, "Too many probability slots" );
  }

  ProbabilityList *pd_power = copy_probability_list( pl );
  ProbabilityList *pd_result = NULL;
  ProbabilityList *pd_next = NULL;
  int power = 1;
  while ( 1 ) {
    if ( power & n ) {
      if ( pd_result ) {
        pd_next = pl_add_distributions( pd_result, pd_power );
        destroy_probability_list( pd_result );
        pd_result = pd_next;
      } else {
        pd_result = copy_probability_list( pd_power );
      }
    }
    power = power << 1;
    if ( power > n ) break;
    pd_next = pl_add_distributions( pd_power, pd_power );
    destroy_probability_list( pd_power );
    pd_power = pd_next;
  }
  destroy_probability_list( pd_power );

  return pd_result;
}

// Assigns { p_rejected, p_maybe, p_kept } to buffer
static void calc_p_table( ProbabilityList *pl, int q, int kbest, double *buffer ) {
  if ( kbest ) {
    buffer[2] = pl_p_gt( pl, q );
    buffer[1] = pl_p_eql( pl, q );
    buffer[0] = pl_p_lt( pl, q );
  } else {
    buffer[2] = pl_p_lt( pl, q );
    buffer[1] = pl_p_eql( pl, q );
    buffer[0] = pl_p_gt( pl, q );
  }
  return;
}

// Assigns a list of pl variants to a buffer
static void calc_keep_distributions( ProbabilityList *pl, int k, int q, int kbest, ProbabilityList **pl_array ) {
  // Init array
  int n;
  for ( n=0; n<k; n++) { pl_array[n] = NULL; }
  pl_array[0] = new_basic_pl( 1, 1.0, q * k );
  ProbabilityList *pl_kd;

  if ( kbest ) {
    if ( pl_p_gt( pl, q ) > 0.0 && k > 1 ) {
      pl_kd = pl_given_ge( pl, q + 1 );
      for ( n = 1; n < k; n++ ) {
        pl_array[n] = pl_repeat_sum( pl_kd, n );
        (pl_array[n])->offset += q * ( k - n );
      }
    }
  } else {
    if ( pl_p_lt( pl, q ) > 0.0 && k > 1 ) {
      pl_kd = pl_given_le( pl, q - 1 );
      for ( n = 1; n < k; n++ ) {
        pl_array[n] = pl_repeat_sum( pl_kd, n );
        (pl_array[n])->offset += q * ( k - n );
      }
    }
  }

  return;
}

static inline void clear_pl_array( int k, ProbabilityList **pl_array  ) {
  int n;
  for ( n=0; n<k; n++) {
    if ( pl_array[n] != NULL ) {
      destroy_probability_list( pl_array[n] );
    }
  }
  return;
}

static ProbabilityList *pl_repeat_n_sum_k( ProbabilityList *pl, int n, int k, int kbest ) {
  if ( n < 1 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate repeat_n_sum_k when n < 1" );
  }
  if ( k < 1 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate repeat_sum_k when k < 1" );
  }
  if ( k >= n ) {
    return pl_repeat_sum( pl, n );
  }
  if ( k * pl->slots - k >= 1000000 ) {
    rb_raise( rb_eRuntimeError, "Too many probability slots" );
  }
  if ( n > 170 ) {
    rb_raise( rb_eRuntimeError, "Too many dice to calculate combinations" );
  }

  // Init target
  ProbabilityList *pl_result = create_probability_list();
  double *pr = alloc_probs_iv( pl_result, 1 + k * (pl->slots - 1), 0.0 );
  pl_result->offset = pl->offset * k;

  // Table of probabilities ( reject, maybe, keep ) for each "pivot point"
  double p_table[3];
  int keep_combos[3];
  // Table of distributions for each count of > pivot point (vs == pivot point)
  ProbabilityList *keep_distributions[171];
  ProbabilityList *kd;

  int d = n - k;
  int i, j, q, dn, kn, mn, kdq;
  double p_sequence;

  for ( i = 0; i < pl->slots; i++ ) {
    if ( ! pl->probs[i] > 0.0 ) continue;

    q = i + pl->offset;
    calc_keep_distributions( pl, k, q, kbest, keep_distributions );
    calc_p_table( pl, q, kbest, p_table );

    for ( kn = 0; kn < k; kn++ ) {
      // Construct keepers. maybes, discards (just counts of these) . . .
      if ( kn > 0 && ! ( p_table[2] > 0.0 ) ) continue;

      for ( dn = 0; dn <= d; dn++ ) {
        mn = (k - kn) + ( d - dn );
        if ( dn > 0 && ! ( p_table[0] > 0.0 ) ) continue;
        p_sequence = 1.0;
        for ( j = 0; j < dn; j++ ) { p_sequence *= p_table[0]; }
        for ( j = 0; j < mn; j++ ) { p_sequence *= p_table[1]; }
        for ( j = 0; j < kn; j++ ) { p_sequence *= p_table[2]; }
        keep_combos[0] = dn;
        keep_combos[1] = mn;
        keep_combos[2] = kn;
        p_sequence *= num_arrangements( keep_combos, 3 );
        kd = keep_distributions[ kn ];

        for ( j = 0; j < kd->slots; j++ ) {
          kdq = j + kd->offset;
          pr[ kdq - pl_result->offset ] += p_sequence * kd->probs[ j ];
        }
      }
    }
    clear_pl_array( k, keep_distributions );
  }

  calc_cumulative( pl_result );
  return pl_result;
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

static void assert_value_wraps_pl( VALUE obj ) {
  if ( TYPE(obj) != T_DATA ||
      RDATA(obj)->dfree != (RUBY_DATA_FUNC)destroy_probability_list) {
    rb_raise( rb_eTypeError, "Expected a Probabilities object, but got something else" );
  }
}

// Validate key/value from hash, and adjust object properties as required
int validate_key_value( VALUE key, VALUE val, VALUE obj ) {
  int k = NUM2INT( key );
  double v = NUM2DBL( val );
  ProbabilityList *pl = get_probability_list( obj );
  if ( k < pl->offset ) {
    if ( pl->slots < 1 ) {
      pl->slots = 1;
    } else {
      pl->slots = pl->slots - k + pl->offset;
    }
    pl->offset = k;
  } else if ( k - pl->offset >= pl->slots ) {
    pl->slots = 1 + k - pl->offset;
  }
  return ST_CONTINUE;
}

// Copy key/value from hash
int copy_key_value( VALUE key, VALUE val, VALUE obj ) {
  int k = NUM2INT( key );
  double v = NUM2DBL( val );
  ProbabilityList *pl = get_probability_list( obj );
  pl->probs[ k - pl->offset ] = v;
  return ST_CONTINUE;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Ruby class and instance methods for Probabilities
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
    double p_item = NUM2DBL( rb_ary_entry( arr, i ) );
    if ( p_item < 0.0 ) {
      rb_raise( rb_eArgError, "Negative probability not allowed" );
    } else if ( p_item > 1.0 ) {
      rb_raise( rb_eArgError, "Probability must be in range 0.0..1.0" );
    }
    pr[i] = p_item;
  }
  double error = calc_cumulative( pl ) - 1.0;
  if ( error < -1.0e-8 ) {
    rb_raise( rb_eArgError, "Total probabilities are less than 1.0" );
  } else if ( error > 1.0e-8 ) {
    rb_raise( rb_eArgError, "Total probabilities are greater than 1.0" );
  }
  return self;
}


static VALUE probabilities_initialize_copy( VALUE copy, VALUE orig ) {
  if (copy == orig) return copy;
  ProbabilityList *pl_copy = get_probability_list( copy );
  ProbabilityList *pl_orig = get_probability_list( orig );

  double *pr = alloc_probs( pl_copy, pl_orig->slots );
  pl_copy->offset = pl_orig->offset;
  memcpy( pr, pl_orig->probs, pl_orig->slots * sizeof(double) );
  memcpy( pl_copy->cumulative, pl_orig->cumulative, pl_orig->slots * sizeof(double) );;

  return copy;
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

VALUE probabilites_p_gt( VALUE self, VALUE target ) {
  return DBL2NUM( pl_p_gt( get_probability_list( self ), NUM2INT(target) ) );
}

VALUE probabilites_p_ge( VALUE self, VALUE target ) {
  return DBL2NUM( pl_p_ge( get_probability_list( self ), NUM2INT(target) ) );
}

VALUE probabilites_p_le( VALUE self, VALUE target ) {
  return DBL2NUM( pl_p_le( get_probability_list( self ), NUM2INT(target) ) );
}

VALUE probabilites_p_lt( VALUE self, VALUE target ) {
  return DBL2NUM( pl_p_lt( get_probability_list( self ), NUM2INT(target) ) );
}

VALUE probabilites_expected( VALUE self ) {
  return DBL2NUM( pl_expected( get_probability_list( self ) ) );
}

VALUE probabilities_given_ge( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  ProbabilityList *pl = get_probability_list( self );
  return pl_as_ruby_class( pl_given_ge( pl, t ), Probabilities );
}

VALUE probabilities_given_le( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  ProbabilityList *pl = get_probability_list( self );
  return pl_as_ruby_class( pl_given_le( pl, t ), Probabilities );
}

VALUE probabilities_repeat_sum( VALUE self, VALUE nsum ) {
  int n = NUM2INT(nsum);
  ProbabilityList *pl = get_probability_list( self );
  return pl_as_ruby_class( pl_repeat_sum( pl, n ), Probabilities );
}

static VALUE probabilities_repeat_n_sum_k( int argc, VALUE* argv, VALUE self ) {
  VALUE nsum, nkeepers, kmode;
  rb_scan_args( argc, argv, "21", &nsum, &nkeepers, &kmode );
  int keep_best = 1;
  if (NIL_P(kmode)) {
    keep_best = 1;
  } else if ( rb_intern("keep_worst") == SYM2ID(kmode) ) {
    keep_best = 0;
  } else if ( rb_intern("keep_best") != SYM2ID(kmode) ) {
    rb_raise( rb_eArgError, "Keep mode not recognised" );
  }

  int n = NUM2INT(nsum);
  int k = NUM2INT(nkeepers);
  ProbabilityList *pl = get_probability_list( self );
  return pl_as_ruby_class( pl_repeat_n_sum_k( pl, n, k, keep_best ), Probabilities );
}

VALUE probabilities_each( VALUE self ) {
  ProbabilityList *pl = get_probability_list( self );
  int i;
  double *pr = pl->probs;
  int o = pl->offset;
  for ( i = 0; i < pl->slots; i++ ) {
    if ( pr[i] > 0.0 ) {
      VALUE a = rb_ary_new2( 2 );
      rb_ary_store( a, 0, INT2NUM( i + o ));
      rb_ary_store( a, 1, DBL2NUM( pr[i] ));
      rb_yield( a );
    }
  }
  return self;
}

VALUE probabilities_for_fair_die( VALUE self, VALUE sides ) {
  int s = NUM2INT( sides );
  if ( s < 1 ) {
    rb_raise( rb_eArgError, "Number of sides should be 1 or more" );
  }
  if ( s > 100000 ) {
    rb_raise( rb_eArgError, "Number of sides should be less than 100001" );
  }
  VALUE obj = pl_alloc( Probabilities );
  ProbabilityList *pl = get_probability_list( obj );
  pl->offset = 1;
  alloc_probs_iv( pl, s, 1.0/s );
  return obj;
}

VALUE probabilities_from_h( VALUE self, VALUE hash ) {
  VALUE obj = pl_alloc( Probabilities );
  ProbabilityList *pl = get_probability_list( obj );
  // Set these up so that they get adjusted during hash iteration
  pl->offset = 2000000000;
  pl->slots = 0;
  // First iteration establish min/max and validate all key/values
  rb_hash_foreach( hash, validate_key_value, obj );

  double *pr = alloc_probs_iv( pl, pl->slots, 0.0 );
  // Second iteration copy key/value pairs into structure
  rb_hash_foreach( hash, copy_key_value, obj );

  double error = calc_cumulative( pl ) - 1.0;
  if ( error < -1.0e-8 ) {
    rb_raise( rb_eArgError, "Total probabilities are less than 1.0" );
  } else if ( error > 1.0e-8 ) {
    rb_raise( rb_eArgError, "Total probabilities are greater than 1.0" );
  }
  return obj;
}

VALUE probabilities_add_distributions( VALUE self, VALUE gdpa, VALUE gdpb ) {
  assert_value_wraps_pl( gdpa );
  assert_value_wraps_pl( gdpb );
  ProbabilityList *pl_a = get_probability_list( gdpa );
  ProbabilityList *pl_b = get_probability_list( gdpb );
  return pl_as_ruby_class( pl_add_distributions( pl_a, pl_b ), Probabilities );
}

VALUE probabilities_add_distributions_mult( VALUE self, VALUE m_a, VALUE gdpa, VALUE m_b, VALUE gdpb ) {
  assert_value_wraps_pl( gdpa );
  assert_value_wraps_pl( gdpb );
  int mul_a = NUM2INT( m_a );
  ProbabilityList *pl_a = get_probability_list( gdpa );
  int mul_b = NUM2INT( m_b );
  ProbabilityList *pl_b = get_probability_list( gdpb );
  return pl_as_ruby_class( pl_add_distributions_mult( mul_a, pl_a, mul_b, pl_b ), Probabilities );
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Setup Probabilities class for Ruby interpretter
//

void init_probabilities_class( VALUE ParentModule ) {
  Probabilities = rb_define_class_under( ParentModule, "Probabilities", rb_cObject );
  rb_define_alloc_func( Probabilities, pl_alloc );
  rb_define_method( Probabilities, "initialize", probabilities_initialize, 2 );
  rb_define_method( Probabilities, "initialize_copy", probabilities_initialize_copy, 1 );
  rb_define_method( Probabilities, "to_h", probabilities_to_h, 0 );
  rb_define_method( Probabilities, "min", probabilities_min, 0 );
  rb_define_method( Probabilities, "max", probabilities_max, 0 );
  rb_define_method( Probabilities, "p_eql", probabilites_p_eql, 1 );
  rb_define_method( Probabilities, "p_gt", probabilites_p_gt, 1 );
  rb_define_method( Probabilities, "p_ge", probabilites_p_ge, 1 );
  rb_define_method( Probabilities, "p_le", probabilites_p_le, 1 );
  rb_define_method( Probabilities, "p_lt", probabilites_p_lt, 1 );
  rb_define_method( Probabilities, "expected", probabilites_expected, 0 );
  rb_define_method( Probabilities, "each", probabilities_each, 0 );
  rb_define_method( Probabilities, "given_ge", probabilities_given_ge, 1 );
  rb_define_method( Probabilities, "given_le", probabilities_given_le, 1 );
  rb_define_method( Probabilities, "repeat_sum", probabilities_repeat_sum, 1 );
  rb_define_method( Probabilities, "repeat_n_sum_k", probabilities_repeat_n_sum_k, -1 );
  rb_define_singleton_method( Probabilities, "for_fair_die", probabilities_for_fair_die, 1 );
  rb_define_singleton_method( Probabilities, "add_distributions", probabilities_add_distributions, 2 );
  rb_define_singleton_method( Probabilities, "add_distributions_mult", probabilities_add_distributions_mult, 4 );
  rb_define_singleton_method( Probabilities, "from_h", probabilities_from_h, 1 );
  return;
}
