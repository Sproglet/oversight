#ifndef __OVS_EXP_H__
#define __OVS_EXP_H__

#include "types.h"


void exp_dump(Exp *e,int depth,int show_holding_values);
int evaluate_num(Exp *e,DbItem *item);
Exp *parse_full_url_expression(char *text_ptr);
void exp_free(Exp *e,int recursive);
void exp_test();
int evaluate(Exp *e,DbItem *item);

#endif
