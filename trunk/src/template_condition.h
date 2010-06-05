// $Id:$
#ifndef __OVS_TEMPLATE_CONDITION__
#define __OVS_TEMPLATE_CONDITION__

typedef struct output_state_str {
    long value; // The value evaluated for the IF or ELSEIF clause
    int fired; // Number of clauses that have been met so far. This is to handle IF(1) ELSEIF(2) etc.
    int state; // If this clause is met considering parent states.
} OutputState;

void output_state_push(long expression_result); // if
void output_state_eval(long expression_result); //elseif
void output_state_invert() ; // for else
void output_state_pop(); // endif

#endif
