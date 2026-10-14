// ext/games_dice/probabilities.c

#include "probabilities.h"
#include <limits.h>
#include <stdint.h>
#include <math.h>

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

/*
 * Owns the temporary distributions created during one native calculation.
 *
 * A local C pointer does not automatically free its allocation when the
 * function returns. Ruby exceptions can also leave a calculation before
 * ordinary cleanup code runs, including when a later allocation fails.
 *
 * Run the calculation through rb_ensure with cleanup_operation as its
 * cleanup callback. create_probability_list adds each new distribution
 * to owned before allocating its buffers. Its fields start at zero, so
 * cleanup can safely free a partially constructed distribution.
 *
 * owned is the head of a linked list. Each ProbabilityList stores next
 * and owner_link, which points to the pointer that currently refers to
 * that entry. This lets destroy_probability_list unlink an entry when
 * it is freed early, preventing cleanup from freeing it again.
 *
 * When returning a distribution to Ruby, perform_operation wraps it in
 * a Ruby object before detaching it from owned. Ruby then handles its
 * lifetime. If wrapping fails, the operation still owns the distribution
 * and cleanup frees it.
 *
 * Iteration uses the same owner for its snapshot, keeping that storage
 * alive even if a Ruby callback replaces the original distribution.
 * Cleanup frees the snapshot after iteration, including exceptions and
 * early block exits.
 */
typedef struct {
  ProbabilityList *owned; /* Temporary distributions requiring cleanup. */
  ProbabilityList *a, *b; /* Borrowed inputs, not owned by these pointers. */
  int x, y, z;            /* Arguments such as counts, weights and thresholds. */
  int operation;          /* Selects the calculation in perform_operation. */
} ProbabilityOperation;

static int checked_result( int64_t value ) {
  if ( value < INT_MIN || value > INT_MAX ) {
    rb_raise( rb_eRangeError, "Probability result is outside native integer range" );
  }
  return (int)value;
}

static int checked_slots( int64_t slots ) {
  if ( slots < 1 || slots > 1000000 ) {
    rb_raise( rb_eArgError, "Bad number of probability slots" );
  }
  return (int)slots;
}

static int weighted_result( int a, int x, int b, int y ) {
  int64_t ax = (int64_t)a * x, by = (int64_t)b * y;
  if ( (by > 0 && ax > INT64_MAX - by) || (by < 0 && ax < INT64_MIN - by) ) {
    rb_raise( rb_eRangeError, "Probability result is outside native integer range" );
  }
  return checked_result( ax + by );
}

static void detach_probability_list( ProbabilityList *pl ) {
  if ( !pl->owner_link ) return;
  *pl->owner_link = pl->next;
  if ( pl->next ) pl->next->owner_link = pl->owner_link;
  pl->next = NULL;
  pl->owner_link = NULL;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Quick factorials, that fit into doubles. . . the size of this structure sets the
//  maximum possible n in repeat_n_sum_k calculations
//

// There is no point calculating these, a cache of them is just fine.
double nfact[171] = {
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

double num_arrangements( int *args, int nargs ) {
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

ProbabilityList *create_probability_list( ProbabilityOperation *op ) {
  ProbabilityList *pl = ALLOC( ProbabilityList );
  memset( pl, 0, sizeof(ProbabilityList) );
  pl->next = op->owned;
  pl->owner_link = &op->owned;
  if ( op->owned ) op->owned->owner_link = &pl->next;
  op->owned = pl;
  return pl;
}

void destroy_probability_list( ProbabilityList *pl ) {
  if ( !pl ) return;
  detach_probability_list( pl );
  xfree( pl->cumulative );
  xfree( pl->probs );
  xfree( pl );
  return;
}

double *alloc_probs( ProbabilityList *pl, int slots ) {
  double *pr;

  if ( slots < 1 || slots > 1000000 ) {
    rb_raise(rb_eArgError, "Bad number of probability slots");
  }
  pl->slots = slots;

  pr = ALLOC_N( double, slots );
  pl->probs = pr;

  pl->cumulative = ALLOC_N( double, slots );

  return pr;
}

double calc_cumulative( ProbabilityList *pl ) {
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

double *alloc_probs_iv( ProbabilityList *pl, int slots, double iv ) {
  double *pr;
  int i;

  if ( iv < 0.0 || iv > 1.0 ) {
    rb_raise(rb_eArgError, "Bad single probability value");
  }
  pr= alloc_probs( pl, slots );
  for(i=0; i<slots; i++) {
    pr[i] = iv;
  }
  calc_cumulative( pl );
  return pr;
}

ProbabilityList *copy_probability_list( ProbabilityOperation *op, ProbabilityList *orig ) {
  ProbabilityList *pl = create_probability_list( op );
  double *pr;
  pr = alloc_probs( pl, orig->slots );
  pl->offset = orig->offset;
  memcpy( pr, orig->probs, orig->slots * sizeof(double) );
  memcpy( pl->cumulative, orig->cumulative, orig->slots * sizeof(double) );
  return pl;
}

static ProbabilityList *new_basic_pl( ProbabilityOperation *op, int nslots, double iv, int o ) {
  ProbabilityList *pl = create_probability_list( op );
  alloc_probs_iv( pl, nslots, iv );
  pl->offset = o;
  return pl;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Probability List core "native" methods
//

static double pl_p_le( ProbabilityList *pl, int target );

static int pl_min( ProbabilityList *pl ) {
  return pl->offset;
}

static int pl_max( ProbabilityList *pl ) {
  return checked_result( (int64_t)pl->offset + pl->slots - 1 );
}

ProbabilityList *pl_add_distributions( ProbabilityOperation *op, ProbabilityList *pl_a, ProbabilityList *pl_b ) {
  double *pr;
  int s = checked_slots( (int64_t)pl_a->slots + pl_b->slots - 1 );
  int o = checked_result( (int64_t)pl_a->offset + pl_b->offset );
  checked_result( (int64_t)o + s - 1 );
  int i,j;

  ProbabilityList *pl = create_probability_list( op );
  pl->offset = o;
  pr = alloc_probs_iv( pl, s, 0.0 );
  for ( i=0; i < pl_a->slots; i++ ) { for ( j=0; j < pl_b->slots; j++ ) {
    pr[ i + j ] += (pl_a->probs)[i] * (pl_b->probs)[j];
  } }
  calc_cumulative( pl );
  return pl;
}

ProbabilityList *pl_add_distributions_mult( ProbabilityOperation *op, int mul_a, ProbabilityList *pl_a, int mul_b, ProbabilityList *pl_b ) {
  int pts[4] = {
    weighted_result( mul_a, pl_min(pl_a), mul_b, pl_min(pl_b) ),
    weighted_result( mul_a, pl_max(pl_a), mul_b, pl_min(pl_b) ),
    weighted_result( mul_a, pl_min(pl_a), mul_b, pl_max(pl_b) ),
    weighted_result( mul_a, pl_max(pl_a), mul_b, pl_max(pl_b) ) };
  int low = pts[0], high = pts[0];
  for ( int i = 1; i < 4; i++ ) {
    if ( pts[i] < low ) low = pts[i];
    if ( pts[i] > high ) high = pts[i];
  }
  int slots = checked_slots( 1 + (int64_t)high - low );
  ProbabilityList *pl = new_basic_pl( op, slots, 0.0, low );
  for ( int i = 0; i < pl_a->slots; i++ ) {
    for ( int j = 0; j < pl_b->slots; j++ ) {
      int64_t value = (int64_t)mul_a * (i + pl_a->offset) + (int64_t)mul_b * (j + pl_b->offset);
      pl->probs[value - low] += pl_a->probs[i] * pl_b->probs[j];
    }
  }
  calc_cumulative( pl );
  return pl;
}

static double pl_p_eql( ProbabilityList *pl, int target ) {
  int64_t idx = (int64_t)target - pl->offset;
  if ( idx < 0 || idx >= pl->slots ) {
    return 0.0;
  }
  return (pl->probs)[idx];
}

static double pl_p_gt( ProbabilityList *pl, int target ) {
  return 1.0 - pl_p_le( pl, target );
}

static double pl_p_lt( ProbabilityList *pl, int target ) {
  return target == INT_MIN ? 0.0 : pl_p_le( pl, target - 1 );
}

static double pl_p_le( ProbabilityList *pl, int target ) {
  int64_t idx = (int64_t)target - pl->offset;
  if ( idx < 0 ) {
    return 0.0;
  }
  if ( idx >= pl->slots - 1 ) {
    return 1.0;
  }
  return (pl->cumulative)[idx];
}

static double pl_p_ge( ProbabilityList *pl, int target ) {
  return 1.0 - pl_p_lt( pl, target );
}

static double pl_expected( ProbabilityList *pl ) {
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

ProbabilityList *pl_given_ge( ProbabilityOperation *op, ProbabilityList *pl, int target ) {
  int m = pl_min( pl );
  double p, mult;
  double *pr;
  double *new_pr;
  int o,i,s;
  ProbabilityList *new_pl;

  if ( m > target ) {
    target = m;
  }
  p = pl_p_ge( pl, target );
  if ( p <= 0.0 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate given probabilities, divide by zero" );
  }
  mult = 1.0/p;
  s = checked_slots( (int64_t)pl->slots + pl->offset - target );
  pr = pl->probs;

  new_pl = create_probability_list( op );
  new_pl->offset = target;
  new_pr = alloc_probs( new_pl, s );
  o = target - pl->offset;

  for ( i = 0; i < s; i++ ) {
    new_pr[i] = pr[o + i] * mult;
  }
  calc_cumulative( new_pl );
  return new_pl;
}

ProbabilityList *pl_given_le( ProbabilityOperation *op, ProbabilityList *pl, int target ) {
  int m = pl_max( pl );
  double p, mult;
  double *pr;
  double *new_pr;
  int i,s;
  ProbabilityList *new_pl;

  if ( m < target ) {
    target = m;
  }
  p = pl_p_le( pl, target );
  if ( p <= 0.0 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate given probabilities, divide by zero" );
  }
  mult = 1.0/p;
  s = target - pl->offset + 1;
  pr = pl->probs;

  new_pl = create_probability_list( op );
  new_pl->offset = pl->offset;
  new_pr = alloc_probs( new_pl, s );

  for ( i = 0; i < s; i++ ) {
    new_pr[i] = pr[i] * mult;
  }
  calc_cumulative( new_pl );
  return new_pl;
}

ProbabilityList *pl_repeat_sum( ProbabilityOperation *op, ProbabilityList *pl, int n ) {
  ProbabilityList *pd_power = NULL;
  ProbabilityList *pd_result = NULL;
  ProbabilityList *pd_next = NULL;
  unsigned int remaining = (unsigned int)n;

  if ( n < 1 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate repeat_sum when n < 1" );
  }
  if ( (int64_t)n * (pl->slots - 1) >= 1000000 ) {
    rb_raise( rb_eRuntimeError, "Too many probability slots" );
  }

  checked_result( (int64_t)n * pl_min(pl) );
  checked_result( (int64_t)n * pl_max(pl) );
  pd_power = copy_probability_list( op, pl );

  while ( 1 ) {
    if ( remaining & 1 ) {
      if ( pd_result ) {
        pd_next = pl_add_distributions( op, pd_result, pd_power );
        destroy_probability_list( pd_result );
        pd_result = pd_next;
      } else {
        pd_result = copy_probability_list( op, pd_power );
      }
    }
    remaining >>= 1;
    if ( remaining == 0 ) break;
    pd_next = pl_add_distributions( op, pd_power, pd_power );
    destroy_probability_list( pd_power );
    pd_power = pd_next;
  }
  destroy_probability_list( pd_power );

  return pd_result;
}

// Assigns { p_rejected, p_maybe, p_kept } to buffer
void calc_p_table( ProbabilityList *pl, int q, int kbest, double *buffer ) {
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
void calc_keep_distributions( ProbabilityOperation *op, ProbabilityList *pl, int k, int q, int kbest, ProbabilityList **pl_array ) {
  ProbabilityList *pl_kd;

  int n;
  for ( n=0; n<k; n++) { pl_array[n] = NULL; }
  pl_array[0] = new_basic_pl( op, 1, 1.0, checked_result( (int64_t)q * k ) );

  if ( kbest ) {
    if ( pl_p_gt( pl, q ) > 0.0 && k > 1 ) {
      pl_kd = pl_given_ge( op, pl, q + 1 );
      for ( n = 1; n < k; n++ ) {
        pl_array[n] = pl_repeat_sum( op, pl_kd, n );
        (pl_array[n])->offset = checked_result( (int64_t)(pl_array[n])->offset + (int64_t)q * (k - n) );
      }
      destroy_probability_list( pl_kd );
    }
  } else {
    if ( pl_p_lt( pl, q ) > 0.0 && k > 1 ) {
      pl_kd = pl_given_le( op, pl, q - 1 );
      for ( n = 1; n < k; n++ ) {
        pl_array[n] = pl_repeat_sum( op, pl_kd, n );
        (pl_array[n])->offset = checked_result( (int64_t)(pl_array[n])->offset + (int64_t)q * (k - n) );
      }
      destroy_probability_list( pl_kd );
    }
  }

  return;
}

static void clear_pl_array( int k, ProbabilityList **pl_array  ) {
  int n;
  for ( n=0; n<k; n++) {
    if ( pl_array[n] != NULL ) {
      destroy_probability_list( pl_array[n] );
    }
  }
  return;
}

ProbabilityList *pl_repeat_n_sum_k( ProbabilityOperation *op, ProbabilityList *pl, int n, int k, int kbest ) {
  // Table of probabilities ( reject, maybe, keep ) for each "pivot point"
  double p_table[3];
  int keep_combos[3];
  // Table of distributions for each count of > pivot point (vs == pivot point)
  ProbabilityList *keep_distributions[171] = { NULL };
  ProbabilityList *kd;
  ProbabilityList *pl_result = NULL;

  double *pr;
  int d;
  int i, j, q, dn, kn, mn, kdq;
  double p_sequence;

  if ( n < 1 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate repeat_n_sum_k when n < 1" );
  }
  if ( k < 1 ) {
    rb_raise( rb_eRuntimeError, "Cannot calculate repeat_sum_k when k < 1" );
  }
  if ( k >= n ) {
    return pl_repeat_sum( op, pl, n );
  }
  if ( (int64_t)k * (pl->slots - 1) >= 1000000 ) {
    rb_raise( rb_eRuntimeError, "Too many probability slots" );
  }
  if ( n > 170 ) {
    rb_raise( rb_eRuntimeError, "Too many dice to calculate combinations" );
  }

  d = n - k;
  checked_result( (int64_t)k * pl_min(pl) );
  checked_result( (int64_t)k * pl_max(pl) );

  // Init target
  pl_result = create_probability_list( op );
  pr = alloc_probs_iv( pl_result, 1 + k * (pl->slots - 1), 0.0 );
  pl_result->offset = pl->offset * k;

  for ( i = 0; i < pl->slots; i++ ) {
    if ( pl->probs[i] <= 0.0 ) continue;

    q = i + pl->offset;
    calc_keep_distributions( op, pl, k, q, kbest, keep_distributions );
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

static void free_probability_list( void *ptr ) {
  destroy_probability_list( ptr );
}

static size_t probability_list_memsize( const void *ptr ) {
  const ProbabilityList *pl = ptr;
  size_t size = sizeof(ProbabilityList);

  if ( pl == NULL ) return 0;
  if ( pl->probs != NULL ) size += pl->slots * sizeof(double);
  if ( pl->cumulative != NULL ) size += pl->slots * sizeof(double);
  return size;
}

static const rb_data_type_t probability_list_type = {
  .wrap_struct_name = "GamesDice::Probabilities",
  .function = {
    .dmark = NULL,
    .dfree = free_probability_list,
    .dsize = probability_list_memsize,
    .dcompact = NULL,
    .reserved = { NULL }
  },
  .parent = NULL,
  .data = NULL,
  .flags = 0
};

static inline VALUE pl_as_ruby_class( ProbabilityList *pl, VALUE klass ) {
  return TypedData_Wrap_Struct( klass, &probability_list_type, pl );
}

VALUE pl_alloc(VALUE klass) {
  ProbabilityList *pl;
  VALUE obj = TypedData_Make_Struct( klass, ProbabilityList, &probability_list_type, pl );
  return obj;
}

static inline ProbabilityList *get_probability_list( VALUE obj ) {
  ProbabilityList *pl;
  TypedData_Get_Struct( obj, ProbabilityList, &probability_list_type, pl );
  return pl;
}

void assert_value_wraps_pl( VALUE obj ) {
  if ( ! rb_typeddata_is_kind_of( obj, &probability_list_type ) ) {
    rb_raise( rb_eTypeError, "Expected a Probabilities object, but got something else" );
  }
}

enum { OP_ADD, OP_WEIGHTED, OP_GE, OP_LE, OP_REPEAT, OP_KEEP, OP_COPY };

static VALUE cleanup_operation( VALUE data ) {
  ProbabilityOperation *op = (ProbabilityOperation *)data;
  while ( op->owned ) destroy_probability_list( op->owned );
  return Qnil;
}

static VALUE perform_operation( VALUE data ) {
  ProbabilityOperation *op = (ProbabilityOperation *)data;
  ProbabilityList *result;
  switch ( op->operation ) {
    case OP_ADD: result = pl_add_distributions( op, op->a, op->b ); break;
    case OP_WEIGHTED: result = pl_add_distributions_mult( op, op->x, op->a, op->y, op->b ); break;
    case OP_GE: result = pl_given_ge( op, op->a, op->x ); break;
    case OP_LE: result = pl_given_le( op, op->a, op->x ); break;
    case OP_REPEAT: result = pl_repeat_sum( op, op->a, op->x ); break;
    case OP_KEEP: result = pl_repeat_n_sum_k( op, op->a, op->x, op->y, op->z ); break;
    default: result = copy_probability_list( op, op->a ); break;
  }
  VALUE obj = pl_as_ruby_class( result, Probabilities );
  detach_probability_list( result );
  return obj;
}

static VALUE operate( int operation, ProbabilityList *a, ProbabilityList *b, int x, int y, int z ) {
  ProbabilityOperation op = { .owned = NULL, .a = a, .b = b, .x = x, .y = y, .z = z, .operation = operation };
  return rb_ensure( perform_operation, (VALUE)&op, cleanup_operation, (VALUE)&op );
}

/* A staging Ruby object owns buffers across coercion/allocation exceptions. */
static VALUE replace_distribution( VALUE receiver, VALUE staged ) {
  ProbabilityList *old = get_probability_list( receiver );
  RTYPEDDATA_DATA(receiver) = get_probability_list( staged );
  RTYPEDDATA_DATA(staged) = NULL;
  destroy_probability_list( old );
  RB_GC_GUARD(staged);
  return receiver;
}

static double probability_value( VALUE value ) {
  double p = NUM2DBL(value);
  if ( p < 0.0 ) rb_raise( rb_eArgError, "Negative probability not allowed" );
  if ( p > 1.0 ) rb_raise( rb_eArgError, "Probability must be in range 0.0..1.0" );
  if ( !isfinite(p) ) rb_raise( rb_eArgError, "Probability must be finite" );
  return p;
}

static void validate_mass( ProbabilityList *pl ) {
  double error = calc_cumulative( pl ) - 1.0;
  if ( error < -1.0e-8 ) rb_raise( rb_eArgError, "Total probabilities are less than 1.0" );
  if ( error > 1.0e-8 ) rb_raise( rb_eArgError, "Total probabilities are greater than 1.0" );
}

static int normalize_pair( VALUE key, VALUE value, VALUE normalized ) {
  int k = NUM2INT(key);
  double p = probability_value(value);
  rb_hash_aset( normalized, INT2NUM(k), DBL2NUM(p) );
  return ST_CONTINUE;
}

static int hash_bounds( VALUE key, VALUE value, VALUE data ) {
  int *bounds = (int *)data;
  int k = NUM2INT(key);
  (void)value;
  if ( k < bounds[0] ) bounds[0] = k;
  if ( k > bounds[1] ) bounds[1] = k;
  return ST_CONTINUE;
}

static int copy_pair( VALUE key, VALUE value, VALUE data ) {
  ProbabilityList *pl = (ProbabilityList *)data;
  pl->probs[NUM2INT(key) - pl->offset] = NUM2DBL(value);
  return ST_CONTINUE;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Ruby class and instance methods for Probabilities
//

/*
 * @overload initialize(probs, offset)
 *   Creates new instance of GamesDice::Probabilities.
 *   @param [Array<Float>] probs Each entry in the array is the probability of getting a result
 *   @param [Integer] offset The result associated with index of 0 in the array
 *   @return [GamesDice::Probabilities]
 */
VALUE probabilities_initialize( VALUE self, VALUE arr, VALUE offset ) {
  rb_check_frozen(self);
  int o = NUM2INT(offset);
  Check_Type( arr, T_ARRAY );
  int slots = checked_slots( RARRAY_LEN(arr) );
  checked_result( (int64_t)o + slots - 1 );
  VALUE normalized = rb_ary_dup(arr);
  for ( int i = 0; i < slots; i++ ) {
    rb_ary_store( normalized, i, DBL2NUM(probability_value(rb_ary_entry(normalized, i))) );
  }
  VALUE staged = pl_alloc( Probabilities );
  ProbabilityList *pl = get_probability_list( staged );
  pl->offset = o;
  alloc_probs( pl, slots );
  for ( int i = 0; i < slots; i++ ) pl->probs[i] = NUM2DBL(rb_ary_entry(normalized, i));
  validate_mass( pl );
  RB_GC_GUARD(normalized);
  rb_check_frozen(self);
  return replace_distribution( self, staged );
}

/*
 * @overload clone
 *   Cloning an object of this class creates a deep copy of the probabilities hash.
 *   @return [GamesDice::Probabilities]
 */
VALUE probabilities_initialize_copy( VALUE copy, VALUE orig ) {
  if ( copy == orig ) return copy;
  rb_check_frozen(copy);
  VALUE staged = operate( OP_COPY, get_probability_list(orig), NULL, 0, 0, 0 );
  RB_GC_GUARD(orig);
  return replace_distribution( copy, staged );
}

/*
 * A hash representation of the distribution. Each key is an integer result,
 * and the matching value is probability of getting that result. A new hash is generated on each
 * call to this method.
 * @return [Hash]
 */
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

/*
 * @overload min
 *   @!attribute [r] min
 *   Minimum result in the distribution
 *   @return [Integer]
 */
VALUE probabilities_min( VALUE self ) {
  return INT2NUM( pl_min(  get_probability_list( self ) ) );
}

/*
 * @overload max
 *   @!attribute [r] max
 *   Maximum result in the distribution
 *   @return [Integer]
 */
VALUE probabilities_max( VALUE self ) {
  return INT2NUM( pl_max( get_probability_list( self ) ) );
}

/*
 * Probability of result equalling specific target
 * @param [Integer] target
 * @return [Float] in range (0.0..1.0)
 */
VALUE probabilites_p_eql( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  return DBL2NUM( pl_p_eql( get_probability_list( self ), t ) );
}

/*
 * Probability of result being greater than specific target
 * @param [Integer] target
 * @return [Float] in range (0.0..1.0)
 */
VALUE probabilites_p_gt( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  return DBL2NUM( pl_p_gt( get_probability_list( self ), t ) );
}

/*
 * Probability of result being equal to or greater than specific target
 * @param [Integer] target
 * @return [Float] in range (0.0..1.0)
 */
VALUE probabilites_p_ge( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  return DBL2NUM( pl_p_ge( get_probability_list( self ), t ) );
}

/*
 * Probability of result being equal to or less than specific target
 * @param [Integer] target
 * @return [Float] in range (0.0..1.0)
 */
VALUE probabilites_p_le( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  return DBL2NUM( pl_p_le( get_probability_list( self ), t ) );
}

/*
 * Probability of result being less than specific target
 * @param [Integer] target
 * @return [Float] in range (0.0..1.0)
 */
VALUE probabilites_p_lt( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  return DBL2NUM( pl_p_lt( get_probability_list( self ), t ) );
}

/*
 * @overload expected
 *   @!attribute [r] expected
 *   Expected value of distribution.
 *   @return [Float]
 */
VALUE probabilites_expected( VALUE self ) {
  return DBL2NUM( pl_expected( get_probability_list( self ) ) );
}

/*
 * Probability distribution derived from this one, where we know (or are only interested in
 * situations where) the result is greater than or equal to target.
 * @param [Integer] target
 * @return [GamesDice::Probabilities] new distribution.
 */
VALUE probabilities_given_ge( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  ProbabilityList *pl = get_probability_list( self );
  VALUE result = operate( OP_GE, pl, NULL, t, 0, 0 );
  RB_GC_GUARD(self);
  return result;
}

/*
 * Probability distribution derived from this one, where we know (or are only interested in
 * situations where) the result is less than or equal to target.
 * @param [Integer] target
 * @return [GamesDice::Probabilities] new distribution.
 */
VALUE probabilities_given_le( VALUE self, VALUE target ) {
  int t = NUM2INT(target);
  ProbabilityList *pl = get_probability_list( self );
  VALUE result = operate( OP_LE, pl, NULL, t, 0, 0 );
  RB_GC_GUARD(self);
  return result;
}

/*
 * @overload repeat_sum(n)
 *   Adds a distribution to itself repeatedly, to simulate a number of dice
 *   results being summed.
 *   @param [Integer] n Number of repetitions, must be at least 1
 *   @return [GamesDice::Probabilities] new distribution
 */
VALUE probabilities_repeat_sum( VALUE self, VALUE nsum ) {
  int n = NUM2INT(nsum);
  ProbabilityList *pl = get_probability_list( self );
  VALUE result = operate( OP_REPEAT, pl, NULL, n, 0, 0 );
  RB_GC_GUARD(self);
  return result;
}

/* 
 * @overload repeat_n_sum_k(n, k, kmode = :keep_best)
 *   Calculates distribution generated by summing best k results of n iterations
 *   of the distribution.
 *   @param [Integer] n Number of repetitions, must be at least 1
 *   @param [Integer] k Number of best results to keep and sum
 *   @return [GamesDice::Probabilities] new distribution
 */
VALUE probabilities_repeat_n_sum_k( int argc, VALUE* argv, VALUE self ) {
  VALUE nsum, nkeepers, kmode;
  int keep_best, n, k;
  ProbabilityList *pl;

  rb_scan_args( argc, argv, "21", &nsum, &nkeepers, &kmode );

  keep_best = 1;
  if (NIL_P(kmode)) {
    keep_best = 1;
  } else if ( rb_intern("keep_worst") == SYM2ID(kmode) ) {
    keep_best = 0;
  } else if ( rb_intern("keep_best") != SYM2ID(kmode) ) {
    rb_raise( rb_eArgError, "Keep mode not recognised" );
  }

  n = NUM2INT(nsum);
  k = NUM2INT(nkeepers);
  pl = get_probability_list( self );
  VALUE result = operate( OP_KEEP, pl, NULL, n, k, keep_best );
  RB_GC_GUARD(self);
  return result;
}

static VALUE yield_probability_pairs( VALUE data ) {
  ProbabilityOperation *op = (ProbabilityOperation *)data;
  /* Keep the snapshot native-owned until every callback has finished. */
  ProbabilityList *pl = copy_probability_list( op, op->a );
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
  return Qnil;
}

/*
 * Iterates through value, probability pairs
 * @yieldparam [Integer] result A result that may be possible in the dice scheme
 * @yieldparam [Float] probability Probability of result, in range 0.0..1.0
 * @return [GamesDice::Probabilities] this object
 */
VALUE probabilities_each( VALUE self ) {
  /* Ruby callbacks may replace self's storage through marshal_load/initialize. */
  ProbabilityOperation op = { .owned = NULL, .a = get_probability_list(self) };
  rb_ensure( yield_probability_pairs, (VALUE)&op, cleanup_operation, (VALUE)&op );
  return self;
}

/*
 * Distribution for a die with equal chance of rolling 1..N
 * @param [Integer] sides Number of sides on die
 * @return [GamesDice::Probabilities]
 */
VALUE probabilities_for_fair_die( VALUE self, VALUE sides ) {
  int s = NUM2INT( sides );
  VALUE obj;
  ProbabilityList *pl;

  if ( s < 1 ) {
    rb_raise( rb_eArgError, "Number of sides should be 1 or more" );
  }
  if ( s > 100000 ) {
    rb_raise( rb_eArgError, "Number of sides should be less than 100001" );
  }
  obj = pl_alloc( Probabilities );
  pl = get_probability_list( obj );
  pl->offset = 1;
  alloc_probs_iv( pl, s, 1.0/s );
  return obj;
}

/* 
 * @overload from_h(prob_hash)
 *   Creates new instance of GamesDice::Probabilities.
 *   @param [Hash] prob_hash A hash representation of the distribution, each key is an integer result,
 *     and the matching value is probability of getting that result
 *   @return [GamesDice::Probabilities]
 */
VALUE probabilities_from_h( VALUE self, VALUE hash ) {
  Check_Type( hash, T_HASH );
  VALUE normalized = rb_hash_new();
  VALUE input = rb_hash_dup(hash);
  rb_hash_foreach( input, normalize_pair, normalized );
  RB_GC_GUARD(input);
  int bounds[2] = { INT_MAX, INT_MIN };
  rb_hash_foreach( normalized, hash_bounds, (VALUE)bounds );
  int slots = checked_slots( 1 + (int64_t)bounds[1] - bounds[0] );
  VALUE obj = pl_alloc( Probabilities );
  ProbabilityList *pl = get_probability_list( obj );
  pl->offset = bounds[0];
  alloc_probs_iv( pl, slots, 0.0 );
  rb_hash_foreach( normalized, copy_pair, (VALUE)pl );
  validate_mass( pl );
  RB_GC_GUARD(normalized);
  return obj;
}

/*
 * @overload add_distributions(pd_a, pd_b)
 *   Combines two distributions to create a third, that represents the distribution created when adding
 *   results together.
 *   @param [GamesDice::Probabilities] pd_a First distribution
 *   @param [GamesDice::Probabilities] pd_b Second distribution
 *   @return [GamesDice::Probabilities]
 */
VALUE probabilities_add_distributions( VALUE self, VALUE gdpa, VALUE gdpb ) {
  ProbabilityList *pl_a;
  ProbabilityList *pl_b;

  assert_value_wraps_pl( gdpa );
  assert_value_wraps_pl( gdpb );
  pl_a = get_probability_list( gdpa );
  pl_b = get_probability_list( gdpb );
  VALUE result = operate( OP_ADD, pl_a, pl_b, 0, 0, 0 );
  RB_GC_GUARD(gdpa);
  RB_GC_GUARD(gdpb);
  return result;
}

/*
 * @overload add_distributions_mult(m_a, pd_a, m_b, pd_b)
 *   Combines two distributions with multipliers to create a third, that represents the distribution
 *   created when adding weighted results together.
 *   @param [Integer] m_a Weighting for first distribution
 *   @param [GamesDice::Probabilities] pd_a First distribution
 *   @param [Integer] m_b Weighting for second distribution
 *   @param [GamesDice::Probabilities] pd_b Second distribution
 *   @return [GamesDice::Probabilities]
 */
VALUE probabilities_add_distributions_mult( VALUE self, VALUE m_a, VALUE gdpa, VALUE m_b, VALUE gdpb ) {
  int mul_a, mul_b;
  ProbabilityList *pl_a;
  ProbabilityList *pl_b;

  assert_value_wraps_pl( gdpa );
  assert_value_wraps_pl( gdpb );
  mul_a = NUM2INT( m_a );
  mul_b = NUM2INT( m_b );
  pl_a = get_probability_list( gdpa );
  pl_b = get_probability_list( gdpb );
  VALUE result = operate( OP_WEIGHTED, pl_a, pl_b, mul_a, mul_b, 0 );
  RB_GC_GUARD(gdpa);
  RB_GC_GUARD(gdpb);
  return result;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Setup Probabilities class for Ruby interpretter
//

void init_probabilities_class(void) {
  VALUE GamesDice = rb_define_module("GamesDice");
  Probabilities = rb_define_class_under( GamesDice, "Probabilities", rb_cObject );
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
