#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <assert.h>
#include <ctype.h>
#include <regex.h>

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

//TODO Add macro or inline function to check access to val members is consistent with val.type

static int evaluate_with_err(Exp *e,DbItem *item,int *err);
int exp_compile(Exp *e,Exp *source);

Exp *new_val_str(char *s,int free_str)
{
    Exp *e = CALLOC(sizeof(Exp),1);
    e->op = OP_CONSTANT;
    e->val.type = VAL_TYPE_STR;
    e->val.str_val = s;
    e->val.free_str = free_str;
    HTML_LOG(0,"str value [%s]",s);
    return e;
}

Exp *new_val_num(double d)
{
    Exp *e = CALLOC(sizeof(Exp),1);
    e->op = OP_CONSTANT;
    e->val.type = VAL_TYPE_NUM;
    e->val.num_val = d;
    HTML_LOG(0,"num value [%ld]",d);
    return e;
}
Exp *new_exp(Op op,Exp *left,Exp *right)
{
    Exp *e = CALLOC(sizeof(Exp),1);
    e->op = op;
    e->subexp[0] = left;
    e->subexp[1] = right;

    // If op = OP_DBFIELD then the fld_* members will get set to save field type lookups.
    e->fld_type = FIELD_TYPE_NONE;
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
        //exp_dump(e,0,1);
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

char *num2str_static(double d) {
    static char s[30];
    if (d == (int)d){
        sprintf(s,"%.0lf",d);
    } else {
        sprintf(s,"%.1lf",d);
    }
    return s;
}


static int evaluate_with_err(Exp *e,DbItem *item,int *err)
{
    if (*err) return *err;

    switch (e->op) {
        case OP_CONSTANT:
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
                                e->val.num_val = compare(e->op,index_STRCMP(e->subexp[0]->val.str_val,e->subexp[1]->val.str_val));
                                break;
                            case VAL_TYPE_CHAR:
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
                    //exp_dump(e->subexp[1],0,1);

                    // INT/STR = not supported
                    // INT/INT = not supported
                    // INT/LIST = not supported
                    //
                    // STR/STR = string functions
                    // STR/INT = string functions
                    // LIST/STR = string functions
                    // LIST/INT = group function
                    //
                    // LIST/LIST = not supported
                    // STR/LIST = not supported
                    // INT/LIST = not supported
                    char *left=NULL;
                    char *right=NULL;
                    int imdb_list_check = 0;

                    int char_on_right = 0;

                    char right_chr = '\0';

                    switch(e->subexp[1]->val.type) {
                        case VAL_TYPE_IMDB_LIST:
                            html_error("2nd list argument not supported");
                            assert(0);
                            break;
                        case VAL_TYPE_STR:
                            right = e->subexp[1]->val.str_val;
                            break;
                        case VAL_TYPE_CHAR:
                            right_chr = e->subexp[1]->val.num_val;
                            char_on_right = 1;
                            break;
                        case VAL_TYPE_NUM:

                            if (e->subexp[0]->val.type == VAL_TYPE_STR) {

                                right = num2str_static(e->subexp[1]->val.num_val);

                            } else if (e->subexp[0]->val.type == VAL_TYPE_IMDB_LIST) {
                                imdb_list_check = 1;
                            }
                            break;
                    }

                    switch(e->subexp[0]->val.type) {
                        case VAL_TYPE_CHAR:
                            html_error("1st character argument not supported");
                            assert(0);
                            break;
                        case VAL_TYPE_NUM:
                            html_error("1st numeric argument not supported");
                            assert(0);
                            break;
                        case VAL_TYPE_IMDB_LIST:
                            if (!imdb_list_check) {
                                left = db_group_imdb_string_static(e->subexp[0]->val.imdb_list_val);
                            } 
                            break;
                        case VAL_TYPE_STR:
                            left = e->subexp[0]->val.str_val;
                            break;
                    }
                    e->val.type = VAL_TYPE_NUM;
                    if (imdb_list_check) {
                        int id = e->subexp[1]->val.num_val;
                        int in_list = id_in_db_imdb_group(id,e->subexp[0]->val.imdb_list_val);
                        e->val.num_val = in_list;

                    } else if (char_on_right) {
                        // String contains character
                        switch(e->op) {
                            case OP_STARTS_WITH:
                                if (STARTS_WITH_THE(left)) left+= 4;
                                e->val.num_val = (tolower(*left) == tolower(right_chr));
                                break;
                            case OP_CONTAINS:
                                e->val.num_val = (strchr(left,right_chr) != NULL);
                                break;
                            default:
                                assert(0);
                        }

                    } else {

                        // String contains string
                        switch(e->op) {
                            case OP_STARTS_WITH:
                                if (STARTS_WITH_THE(left)) left+= 4;
                                e->val.num_val = util_starts_with_ignore_case(left,right);
                                break;
                            case OP_CONTAINS:
                                e->val.num_val = (util_strcasestr(left,right) != NULL);
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
                char *fname =e->subexp[0]->val.str_val;

                if (e->subexp[0]->val.type != VAL_TYPE_STR) {

                    html_error("string value expected");
                    *err = __LINE__;

                } else {

                    if (e->fld_type == FIELD_TYPE_NONE || e->subexp[0]->op != OP_CONSTANT ) {

                        // Get the field attributes. Type, offset in DbItem, 
                        // whether it is an overview field (or only parsed during detail view - eg PLOT)
                       
                        //HTML_LOG(0,"Fetching field details for [%s]",fname);
                        if (!db_rowid_get_field_offset_type(item,fname,&offset,&(e->fld_type),&(e->fld_overview),&(e->fld_imdb_prefix))) {

                            html_error("bad field [%s]",fname);
                            *err = __LINE__;
                        } else {
                            e->fld_offset = (char *)offset - (char *)item;
                        }

                    }

                    offset = (char *)item + e->fld_offset;

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
                    switch(e->fld_type){

                        case FIELD_TYPE_STR:
                            e->val.type = VAL_TYPE_STR;
                            e->val.free_str = 0;
                            e->val.str_val = *(char **)offset;
                            break;

                        case FIELD_TYPE_CHAR:
                            e->val.type = VAL_TYPE_CHAR;
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

                            e->val.type = VAL_TYPE_IMDB_LIST;
                            e->val.free_str = 0;
                            e->val.imdb_list_val = *(DbGroupIMDB **)offset;
                            break;

                        case FIELD_TYPE_DATE:
                        case FIELD_TYPE_TIMESTAMP:

                        case FIELD_TYPE_DOUBLE:
                        case FIELD_TYPE_NONE:
                            html_error("unsupported field type [%c]",e->fld_type);
                            break;

                        default:
                            html_error("unknown field type [%c]",e->fld_type);
                            *err = __LINE__;
                    }
                }
            }
            break;

        case OP_REGEX_CONTAINS:
        case OP_REGEX_STARTS_WITH:
        case OP_REGEX_MATCH:
            if (evaluate_with_err(e->subexp[0],item,err) == 0) {
                if (evaluate_with_err(e->subexp[1],item,err) == 0) {
                    if (exp_compile(e,e->subexp[1]) == 0) {
                        e->val.type=VAL_TYPE_NUM;
                        //HTML_LOG(0,"[%s] vs [%s]",e->subexp[0]->val.str_val,e->regex_str);
                        e->val.num_val = (regexec(e->regex,e->subexp[0]->val.str_val,0,NULL,0) == 0);
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

int exp_compile(Exp *e,Exp *source)
{
    int result = 0;
    // Only compile strings
    assert(source->val.type == VAL_TYPE_STR);

    if ( e->regex_str == NULL || // first time
        (source->op != OP_CONSTANT && STRCMP(e->regex_str,source->val.str_val) != 0) // not a constant and value has changed
        
        )  {
        // Free the old pattern
        if (e->regex) {
            regfree(e->regex);
        } else {
            e->regex = MALLOC(sizeof(regex_t));
        }

        FREE(e->regex_str);

        // Store the new string
        e->regex_str = STRDUP(source->val.str_val);

        // Add delimiters
        char *tmp;
        ovs_asprintf(&tmp,"%s%s%s",
                (e->op == OP_REGEX_CONTAINS ? "" : "^" ),
                e->regex_str,
                (e->op == OP_REGEX_MATCH ? "$" : "" ));

        HTML_LOG(0,"regex[%s]",tmp);

        // compile it
        if ((result = regcomp(e->regex,tmp,REG_EXTENDED|REG_ICASE)) != 0) {
#define BUFSIZE 256
            char buf[BUFSIZE];
            regerror(result,e->regex,buf,BUFSIZE);
            html_error("%s\n",buf);
            assert(0);
        }
        FREE(tmp);
    }
    return result;
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

    //HTML_LOG(0,"parse exp%d %*s[%s]",precedence,precedence*4,"",*text_ptr);

#define ATOMIC_PRECEDENCE 6
    static OpDetails ops[] = {
        { OP_CONSTANT   , ""    , 0 ,ATOMIC_PRECEDENCE },
        { OP_ADD     , "~A~" , 2 , 3 },
        { OP_SUBTRACT,"~S~"  , 2 , 3 },
        { OP_MULTIPLY,"~M~"  , 2 , 4 },
        { OP_DIVIDE  ,"~D~"  , 2 , 4 },
        { OP_AND     ,"~a~"  , 2 , 0 },
        { OP_OR      ,"~o~"  , 2 , 0 },
        { OP_NOT      ,"~!~" , 1 , 5 },
        { OP_NE      ,"~ne~" , 2 , 1 },
        { OP_LE      ,"~le~" , 2 , 2 },
        { OP_LT      ,"~lt~" , 2 , 2 },
        { OP_GT      ,"~gt~" , 2 , 2 },
        { OP_GE      ,"~ge~" , 2 , 2 },

        // Letters used for following operators are passed in URLs also
        { OP_EQ      ,"~" QPARAM_FILTER_EQUALS "~" , 2 , 1 },
        { OP_STARTS_WITH,"~" QPARAM_FILTER_STARTS_WITH "~" , 2 , 2 },
        { OP_CONTAINS,"~" QPARAM_FILTER_CONTAINS "~"  , 2 , 2 },

        { OP_REGEX_STARTS_WITH,"~" QPARAM_FILTER_STARTS_WITH QPARAM_FILTER_REGEX "~" , 2 , 2 },
        { OP_REGEX_CONTAINS,   "~" QPARAM_FILTER_CONTAINS QPARAM_FILTER_REGEX "~"  , 2 , 2 },
        { OP_REGEX_MATCH,      "~" QPARAM_FILTER_EQUALS QPARAM_FILTER_REGEX "~"  , 2 , 2 },

        { OP_DBFIELD,"~f~"   , 1 , 5 }
    };

    static int num_ops = sizeof(ops)/sizeof(ops[0]);

    if (precedence == ATOMIC_PRECEDENCE ) {
        // Parse final value or ( exp )

#define BROPEN "("
#define BRCLOSE ")"

       if (util_starts_with(*text_ptr,BROPEN)) {

            // parse ( exp )
           *text_ptr += strlen(BROPEN);
           result = parse_url_expression(text_ptr,0);
           if (!util_starts_with(*text_ptr,BRCLOSE)) {
               html_error("bad expression [%s]",*text_ptr);
               assert(0);
           }
           *text_ptr += strlen(BRCLOSE);

       } else {

           // parse atomic value
           char *p = *text_ptr;
           char *end_tok="~)";;
           if (*p == '\'') {
               end_tok = "\'";
           } 
           while (*p && strchr(end_tok,*p) == NULL ) { p++; }

           //HTML_LOG(0,"value [%.*s]",p-*text_ptr,*text_ptr);
           if (**text_ptr == '\'' && p[-1] == '\'' ) {
               // quoted string
               char *str = COPY_STRING(p-*text_ptr-2,*text_ptr+1);
               result = new_val_str(str,1);
           } else {
               char *end;
               double d = strtod(*text_ptr,&end);
               if (end != p) {
                   // Could not parse number - set as a string value
                   result = new_val_str(COPY_STRING(p-*text_ptr,*text_ptr),1);
               } else {
                   // numeric value
                   result = new_val_num(d);
               }
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
            HTML_LOG(0,"new op [%s]",op_details->url_text);
            result = new_exp(op_details->op,result,exp2);
        }
    }

    return result;
}

Exp *parse_full_url_expression(char *text_ptr)
{
    Exp *result =  NULL;
    char *p = text_ptr;
    if (p && *p) {
        result = parse_url_expression(&p,0);
        if (*p) {
            html_error("unparsed [%.*s]",20,p);
        }
    }
    HTML_LOG(0,"Exp [%s]=",text_ptr);
    exp_dump(result,0,0);
    return result;

}

void exp_dump(Exp *e,int depth,int show_holding_values)
{
    if (e) {
        exp_dump(e->subexp[0],depth+1,show_holding_values);

        if (e->op != OP_CONSTANT) {
            HTML_LOG(0,"%*s op[%c]",depth*4," ",e->op);
        }
        if (e->op == OP_CONSTANT || show_holding_values) {
            switch(e->val.type) {
                case VAL_TYPE_CHAR:
                    HTML_LOG(0,"%*s char[%c]",depth*4," ",e->val.num_val);
                    break;
                case VAL_TYPE_NUM:
                    HTML_LOG(0,"%*s num[%lf]",depth*4," ",e->val.num_val);
                    break;
                case VAL_TYPE_STR:
                    HTML_LOG(0,"%*s str[%s]",depth*4," ",e->val.str_val);
                    break;
                case VAL_TYPE_IMDB_LIST:
                    HTML_LOG(0,"%*s list[%s]",depth*4," ",db_group_imdb_string_static(e->val.imdb_list_val));
                    break;
            }
        }

        exp_dump(e->subexp[1],depth+1,show_holding_values);
    }
}
void exp_free(Exp *e,int recursive)
{
    if (e) {
        if (recursive)  {
            if (e->op != OP_CONSTANT) {
                exp_free(e->subexp[0],recursive);
                exp_free(e->subexp[1],recursive);
            }
        }
        if (e->val.type == VAL_TYPE_STR && e->val.free_str) {
            FREE(e->val.str_val);
        }
        if (e->regex) {
            regfree(e->regex);
            FREE(e->regex);
        }
        FREE(e->regex_str);
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
