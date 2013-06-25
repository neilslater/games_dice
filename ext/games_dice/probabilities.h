// ext/games_dice/probabilities.h

// definitions for NewProbabilities class

#ifndef PROBABILITIES_H
#define PROBABILITIES_H

#include <ruby.h>

void init_probabilities_class( VALUE ParentModule );

typedef struct _pd {
    int offset;
    double *probs;
  } ProbabilityList;

#endif
