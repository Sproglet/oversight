#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <ctype.h>

#include "types.h"
#include "exp.h"
#include "util.h"
#include "oversight.h"
#include "db.h"
#include "dboverview.h"
#include "dbnames.h"
#include "dbplot.h"
#include "display.h"
#include "gaya_cgi.h"
#include "dbfield.h"
#include "vasprintf.h"
#include "variables.h"

static int evaluate_with_err(Exp *e,DbItem *item,int *err);

Exp *new_val_str(char *s,int free_str)
{
    Exp *e = calloc(sizeof(Exp),1);
    e->op = OP_VALUE;
    e->val.type = VAL_TYPE_STR;
    e->val.str_val = s;
    e->val.free_str = free_str;
    return e;
}

Exp *new_val_num(double d)
{
    Exp *e = calloc(sizeof(Exp),1);
    e->op = OP_VALUE;
    e->val.type = VAL_TYPE_NUM;
    e->val.num_val = d;
    return e;
}
Exp *new_exp(Op op,Exp *left,Exp *right)
{
    Exp *e = calloc(sizeof(Exp),1);
    e->op = op;
    e->subexp[0] = left;
    e->subexp[1] = right;
    return e;
}

int evaluate(Exp *e,DbItem *item)
{
    int result = 0;
    evaluate_with_err(e,item,&result);
    return result;
}

int evaluate_num(Exp *e,DbItem *item)
{
    int result = 0;
    if (e) {
        if (evaluate(e,item) == 0) {
            if (e->val.type == VAL_TYPE_NUM) {
                result = e->val.num_val;
            } else {
                html_error("number expected");
                exp_dump(e,0,1);
                assert(0);
            }
        }
    }
    return result;
}

int compare(Op op,int val) {

    int result=0;
    switch(op) {
        case OP_EQ: result = ( val == 0 ); break;
        case OP_NE: result = ( val != 0 ); break;
        case OP_LE: result = ( val <= 0 ); break;
        case OP_LT: result = ( val < 0 ); break;
        case OP_GT: result = ( val > 0 ); break;
        case OP_GE: result = ( val >= 0 ); break;
        default:
            html_error("unknown operator[%c]",op);
            assert(0);
    }
    return result;
}


static int evaluate_with_err(Exp *e,DbItem *item,int *err)
{
    if (*err) return *err;

    switch (e->op) {
        case OP_VALUE:
            break;
        case OP_ADD:
            e->val.type = VAL_TYPE_NUM;
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                    e->val.num_val = e->subexp[0]->val.num_val + e->subexp[1]->val.num_val;
                }
            }
            break;
        case OP_SUBTRACT:
            e->val.type = VAL_TYPE_NUM;
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                    e->val.num_val = e->subexp[0]->val.num_val - e->subexp[1]->val.num_val;
                }
            }
            break;
        case OP_MULTIPLY:
            e->val.type = VAL_TYPE_NUM;
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                    e->val.num_val = e->subexp[0]->val.num_val * e->subexp[1]->val.num_val;
                }
            }
            break;
        case OP_DIVIDE:
            e->val.type = VAL_TYPE_NUM;
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                    e->val.num_val = e->subexp[0]->val.num_val / e->subexp[1]->val.num_val;
                }
            }
            break;
        case OP_AND:
            e->val.type = VAL_TYPE_NUM;
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                e->val.num_val = e->subexp[0]->val.num_val;
                if (e->val.num_val) {
                    if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                        e->val.num_val = e->subexp[1]->val.num_val;
                    }
                }
            }
            break;
        case OP_OR:
            e->val.type = VAL_TYPE_NUM;
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                e->val.num_val = e->subexp[0]->val.num_val;
                if (!e->val.num_val) {
                    if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                        e->val.num_val = e->subexp[1]->val.num_val;
                    }
                }
            }
            break;
        case OP_NOT:
            e->val.type = VAL_TYPE_NUM;
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                e->val.num_val = !e->subexp[0]->val.num_val;
            }
            break;
        case OP_EQ:
        case OP_NE:
        case OP_LE:
        case OP_LT:
        case OP_GT:
        case OP_GE:
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                    e->val.type = VAL_TYPE_NUM;
                    if (e->subexp[0]->val.type != e->subexp[1]->val.type) {
                        e->val.num_val = 0;
                    } else {
                        switch (e->subexp[0]->val.type ) {
                            case VAL_TYPE_STR:
                                e->val.num_val = compare(e->op,STRCMP(e->subexp[0]->val.str_val,e->subexp[1]->val.str_val));
                                break;
                            case VAL_TYPE_NUM:
                                e->val.num_val = compare(e->op,(e->subexp[0]->val.num_val - e->subexp[1]->val.num_val));
                                break;
                            default:
                                assert(0);
                        }
                    }
                }
            }
            break;
        case OP_STARTS_WITH:
        case OP_CONTAINS:
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                    if (e->subexp[0]->val.type == e->subexp[1]->val.type && e->subexp[0]->val.type == VAL_TYPE_STR ) {

                        e->val.type = VAL_TYPE_NUM;
                        switch(e->op) {
                            case OP_STARTS_WITH:
                                e->val.num_val = util_starts_with(e->subexp[0]->val.str_val,e->subexp[1]->val.str_val);
                                break;
                            case OP_CONTAINS:
                                e->val.num_val = (strstr(e->subexp[0]->val.str_val,e->subexp[1]->val.str_val) != NULL);
                                break;
                            default:
                                assert(0);
                        }
                    }
                }
            }
            break;

        case OP_DBFIELD:

            assert(item);

            if (evaluate_with_err(e->subexp[0],item,err) == 0) {

                //HTML_LOG(0,"OP_DBFIELD item [%s]",item->title);
                //exp_dump(e->subexp[0],0,1);
                

                void *offset;
                char ftype;
                int overview;
                char *imdb_prefix_ptr;
                char *fname =e->subexp[0]->val.str_val;

                if (e->subexp[0]->val.type != VAL_TYPE_STR) {

                    html_error("string value expected");
                    *err = __LINE__;

                } else if (!db_rowid_get_field_offset_type(item,fname,&offset,&ftype,&overview,&imdb_prefix_ptr)) {

                    html_error("bad field [%s]",fname);
                    *err = __LINE__;

                } else {

                    /*
                    char *p = item->title;
                    char *q = *(char **)offset;
                    HTML_LOG(0,"OP_DBFIELD fname [%s]",fname);
                    HTML_LOG(0,"OP_DBFIELD ftype [%c]",ftype);
                    HTML_LOG(0,"OP_DBFIELD item [%lu]",(unsigned long)item);
                    HTML_LOG(0,"OP_DBFIELD item->title [%lu]",(unsigned long)&(item->title));
                    HTML_LOG(0,"OP_DBFIELD offset [%lu]",(unsigned long)offset);
                    HTML_LOG(0,"OP_DBFIELD item->title [%s]",item->title);
                    HTML_LOG(0,"OP_DBFIELD offset [%s]",offset);
                    HTML_LOG(0,"OP_DBFIELD p [%lu] q[%lu]",p,q);
                    HTML_LOG(0,"OP_DBFIELD p [%s] q[%s]",p,q);
                    */
                    switch(ftype){

                        case FIELD_TYPE_STR:
                            e->val.type = VAL_TYPE_STR;
                            e->val.free_str = 0;
                            e->val.str_val = *(char **)offset;
                            break;

                        case FIELD_TYPE_CHAR:
                            e->val.type = VAL_TYPE_NUM;
                            e->val.num_val = *(char *)offset;
                            break;

                        case FIELD_TYPE_LONG:
                            e->val.type = VAL_TYPE_NUM;
                            e->val.num_val = *(long *)offset;
                            break;

                        case FIELD_TYPE_INT:
                        case FIELD_TYPE_YEAR:
                            e->val.type = VAL_TYPE_NUM;
                            e->val.num_val = *(int *)offset;
                            break;

                        case FIELD_TYPE_IMDB_LIST:
                        case FIELD_TYPE_IMDB_LIST_NOEVAL:

                            e->val.type = VAL_TYPE_STR;
                            e->val.free_str = 0;
                            e->val.str_val = NULL;
                            DbGroupIMDB *imdblist = offset;
                            if (imdblist != NULL) {
                                if (!(imdblist->evaluated)) {
                                    evaluate_group(imdblist);
                                }
                                e->val.str_val = db_group_imdb_string_static(imdblist,imdb_prefix_ptr);
                            }
                            break;

                        case FIELD_TYPE_DATE:
                        case FIELD_TYPE_TIMESTAMP:

                        case FIELD_TYPE_DOUBLE:
                        case FIELD_TYPE_NONE:
                            html_error("unsupported field type [%c]",ftype);
                            break;

                        default:
                            html_error("unknown field type [%c]",ftype);
                            *err = __LINE__;
                    }
                }
            }
            break;
        default:
            html_error("unknown op [%d]",e->op);
            assert(0);

    }
    return *err;
}

typedef struct {
    Op op;
    char *url_text;
    int num_args;
    int precedence;
} OpDetails;

/**
 * Convert string to an expression.
 * Operators are
 * ~a~ AND
 * ~o~ OR
 * ~c~ contains
 * ~s~ starts with
 * ~eq~ ~lt~ ~le~ ~gt~ ~ge~ 
 *
 * ~f~nnn = nnn field. eg  ~f~_Y = Year.
 *
 * ~f~_Y~eq~2003
 **/

/**
 * Recursive descent parser
 */
Exp *parse_url_expression(char **text_ptr,int precedence)
{
    Exp *result = NULL;

#define ATOMIC_PRECEDENCE 6
    static OpDetails ops[] = {
        { OP_VALUE   , ""    , 0 ,ATOMIC_PRECEDENCE },
        { OP_ADD     , "~A~" , 2 , 3 },
        { OP_SUBTRACT,"~S~"  , 2 , 3 },
        { OP_MULTIPLY,"~M~"  , 2 , 4 },
        { OP_DIVIDE  ,"~D~"  , 2 , 4 },
        { OP_AND     ,"~a~"  , 2 , 0 },
        { OP_OR      ,"~o~"  , 2 , 0 },
        { OP_NOT      ,"~!~" , 1 , 5 },
        { OP_EQ      ,"~eq~" , 2 , 1 },
        { OP_NE      ,"~ne~" , 2 , 1 },
        { OP_LE      ,"~le~" , 2 , 2 },
        { OP_LT      ,"~lt~" , 2 , 2 },
        { OP_GT      ,"~gt~" , 2 , 2 },
        { OP_GE      ,"~ge~" , 2 , 2 },
        { OP_STARTS_WITH,"~s~" , 2 , 2 },
        { OP_CONTAINS,"~c~"  , 2 , 2 },
        { OP_DBFIELD,"~f~"   , 1 , 5 }
    };

    static int num_ops = sizeof(ops)/sizeof(ops[0]);

    if (precedence == ATOMIC_PRECEDENCE ) {
        // Parse final value or ( exp )

#define BROPEN "("
#define BRCLOSE "("

       if (util_starts_with(*text_ptr,BROPEN)) {

            // parse ( exp )
           *text_ptr += strlen(BROPEN);
           result = parse_url_expression(text_ptr,0);
           assert(util_starts_with(*text_ptr,BRCLOSE));
           *text_ptr += strlen(BRCLOSE);

       } else {

           // parse atomic value
           char *p = *text_ptr;
           while (*p && *p != '~' ) {
               p++;
           }
           //HTML_LOG(0,"value [%.*s]",p-*text_ptr,*text_ptr);
           if (**text_ptr == '\'' && p[-1] == '\'' ) {
               char *str = COPY_STRING(p-*text_ptr-2,*text_ptr+1);
               HTML_LOG(0,"str value [%s]",str);
               result = new_val_str(str,1);
           } else {
               char *end;
               double d = strtod(*text_ptr,&end);
               //HTML_LOG(0,"num value [%lf]%.*s...",d,5,end);
               if (end != p) {
                   html_error("parse double [%.*s] expected [%.*s]",
                           end-*text_ptr,*text_ptr,
                           p-*text_ptr,*text_ptr);
                   assert(0);
               }
               result = new_val_num(d);
           }
           *text_ptr = p;
       }
    }  else {

        // Parse higher level expression
        result = parse_url_expression(text_ptr,precedence+1);

        while(1) {
            // Look for operator at current precedence level
            int i;
            OpDetails *op_details = NULL;
            for(i = 0 ; i < num_ops ; i++ ) {
                if (ops[i].precedence == precedence) {
                    if (util_starts_with(*text_ptr,ops[i].url_text)) {
                        op_details = ops + i ;
                        break;
                    }
                }
            }

            if (!op_details) break;
           
            // Found operator.
            Exp *exp2 = NULL;
            *text_ptr += strlen(op_details->url_text);

            if (op_details->num_args >= 2) {
                // Parse following expression 
                exp2 = parse_url_expression(text_ptr,precedence+1);
            }
            result = new_exp(op_details->op,result,exp2);
        }
    }

    return result;
}

Exp *parse_full_url_expression(char *text_ptr)
{
    Exp *result =  parse_url_expression(&text_ptr,0);
    if (*text_ptr) {
        html_error("unparsed [%.*s]",20,text_ptr);
    }
    return result;

}

void exp_dump(Exp *e,int depth,int show_holding_values)
{
    if (e) {
        exp_dump(e->subexp[0],depth+1,show_holding_values);

        if (e->op != OP_VALUE) {
            HTML_LOG(0,"%*s op[%c]",depth*4," ",e->op);
        }
        if (e->op == OP_VALUE || show_holding_values) {
            if (e->val.type == VAL_TYPE_NUM) {
                HTML_LOG(0,"%*s num[%lf]",depth*4," ",e->val.num_val);
            } else {
                HTML_LOG(0,"%*s str[%s]",depth*4," ",e->val.str_val);
            }
        }

        exp_dump(e->subexp[1],depth+1,show_holding_values);
    }
}
void exp_free(Exp *e,int recursive)
{
    if (e) {
        if (recursive)  {
            if (e->op != OP_VALUE) {
                exp_free(e->subexp[0],recursive);
                exp_free(e->subexp[1],recursive);
            }
        }
        if (e->val.type == VAL_TYPE_STR && e->val.free_str) {
            FREE(e->val.str_val);
        }
        FREE(e);
    }
}

void exp_test_num(char *exp,double expect) {
    Exp *e = parse_full_url_expression(exp);
    evaluate(e,NULL);
    exp_dump(e,0,1);
    if(e->val.num_val!= expect) {
        assert(0);
    } else {
        HTML_LOG(0,"[%s] ok ",exp);
    }
    HTML_LOG(0,"=========================");
    exp_free(e,1);
}
void exp_test() {

    exp_test_num("1~A~2~M~3",7); // + *
    exp_test_num("8~S~35~D~7",3); // - /

    exp_test_num("8~ge~7",1);
    exp_test_num("8~ge~8",1);
    exp_test_num("8~ge~9",0);

    exp_test_num("8~gt~7",1);
    exp_test_num("8~gt~8",0);
    exp_test_num("8~gt~9",0);

    exp_test_num("8~lt~7",0);
    exp_test_num("8~lt~8",0);
    exp_test_num("8~lt~9",1);

    exp_test_num("8~le~7",0);
    exp_test_num("8~le~8",1);
    exp_test_num("8~le~9",1);

    exp_test_num("8~a~7",7);
    exp_test_num("0~a~7",0);
    exp_test_num("8~a~0",0);
    exp_test_num("0~a~0",0);

    exp_test_num("8~o~7",8);
    exp_test_num("0~o~7",7);
    exp_test_num("8~o~0",8);
    exp_test_num("0~o~0",0);

    exp_test_num("8~!~",0);
    exp_test_num("0~!~",1);
    exp_test_num("8~!~~!~",1);

    // string compare
    exp_test_num("'2'~lt~'22'",1);
    exp_test_num("'22'~lt~'222'",1);
    exp_test_num("'2'~lt~'11'",0);
    exp_test_num("2~lt~11",1); // num

    //string functions
    exp_test_num("'abc'~eq~'abc'",1);
    exp_test_num("'abc'~eq~'ab'",0);
    exp_test_num("'abc'~c~'ab'",1);
    exp_test_num("'abc'~c~'abc'",1);
    exp_test_num("'abc'~c~'abcd'",0);

    exp_test_num("'abc'~s~'ab'",1);
    exp_test_num("'abc'~s~'abc'",1);
    exp_test_num("'abc'~s~'abcd'",0);

    // TODO Test Db field values
}
