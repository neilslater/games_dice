// ext/games_dice/probabilities.h

// definitions for NewProbabilities class

#ifndef PROBABILITIES_H
#define PROBABILITIES_H

#include <ruby.h>

void init_probabilities_class( VALUE ParentModule );

typedef struct _pd {
    int offset;
    int slots;
    double *probs;
    double *cumulative;
  } ProbabilityList;

static inline int pl_min( ProbabilityList *pl );

static inline int pl_max( ProbabilityList *pl );

static ProbabilityList *pl_add_distributions( ProbabilityList *pl_a, ProbabilityList *pl_b );

static ProbabilityList *pl_add_distributions_mult( int mul_a, ProbabilityList *pl_a, int mul_b, ProbabilityList *pl_b );

static inline double pl_p_eql( ProbabilityList *pl, int target );

static inline double pl_p_gt( ProbabilityList *pl, int target );

static inline double pl_p_lt( ProbabilityList *pl, int target );

static inline double pl_p_le( ProbabilityList *pl, int target );

static inline double pl_p_ge( ProbabilityList *pl, int target );

static inline double pl_expected( ProbabilityList *pl );

static ProbabilityList *pl_given_ge( ProbabilityList *pl, int target );

static ProbabilityList *pl_given_le( ProbabilityList *pl, int target );

static ProbabilityList *pl_repeat_sum( ProbabilityList *pl, int n );

#endif
