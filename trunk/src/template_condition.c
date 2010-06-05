// $Id:$
#include "template_condition.h"
#include "util.h"
#include "gaya_cgi.h"

/*
 * Stack to manage output state. - called by IF,ELSE,ENDIF macros.
 * IF , and elseif push the expression value to TOS
 * else negates TOS.
 * There is also a value below TOS that indicates if a clause has fired for this 
 * if-elseif-else-endif
 */

static OutputState output_state_stack[100];
static int output_state_tos=-1;

long output_state()
{
    if (output_state_tos >= 0 ) {
        return output_state_stack[output_state_tos].state;
    } else {
        return 1;
    }
}
void output_state_invert() 
{
    if (output_state_tos >= 0) {
        output_state_eval(output_state_stack[output_state_tos].fired == 0);
    }
}

void output_state_eval(long expression_result)
{
    //HTML_LOG(0,"eval(%ld)",expression_result);
    int this_clause_met = (expression_result != 0);
    output_state_stack[output_state_tos].value = expression_result;
    output_state_stack[output_state_tos].fired += this_clause_met;

    // First check parent state
    if (output_state_tos == 0 || output_state_stack[output_state_tos-1].state ) {

        output_state_stack[output_state_tos].state = (output_state_stack[output_state_tos].fired  == 1) && this_clause_met;
    }
}

void output_state_push(long expression_result)
{
    //HTML_LOG(0,"push(%ld)",expression_result);
    output_state_tos++;
    output_state_stack[output_state_tos].state = 0;
    output_state_stack[output_state_tos].fired = 0;

    output_state_eval(expression_result);
    
}

void output_state_pop()
{
    //HTML_LOG(0,"pop");
    if (output_state_tos >= 0 ) { 
        output_state_tos--;
    }
}

void output_state_reset()
{
    output_state_tos = -1;
}
