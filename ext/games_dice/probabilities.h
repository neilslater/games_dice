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
  } ProbabilityList;

static inline int pl_min( ProbabilityList *pl );

static inline int pl_max( ProbabilityList *pl );

static ProbabilityList *pl_add_distributions( ProbabilityList *pl_a, ProbabilityList *pl_b );

static ProbabilityList *pl_add_distributions_mult( int mul_a, ProbabilityList *pl_a, int mul_b, ProbabilityList *pl_b );

static inline double pl_p_eql( ProbabilityList *pl, int target );

#endif
