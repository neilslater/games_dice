// ext/games_dice/probabilities.h

// definitions for NewProbabilities class

#ifndef PROBABILITIES_H
#define PROBABILITIES_H

#include <ruby.h>

void init_probabilities_class(void);

typedef struct _pd {
    struct _pd *next;
    struct _pd **owner_link;
    int offset;
    int slots;
    double *probs;
    double *cumulative;
  } ProbabilityList;

#endif
