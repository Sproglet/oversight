#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "exp.h"
#include "filter.h"
#include "dbfield.h"
#include "oversight.h"
#include "gaya_cgi.h"

//TODO: These ops need to be defined in exp.h
#define FIELD_OP "~f~"
#define EQ_OP "~e~"
#define CONTAINS_OP "~c~"

void add_op_clause(char **val,int allow_empty_parts,char *left,char *op,char *right);

/**
 * Look at html query info and build an expression to filter the database
 */
Exp *build_filter(char *media_types) 
{
    Exp *result = NULL;
    char *val=NULL;
    add_op_clause(&val,0,DB_FLDID_SEASON FIELD_OP,EQ_OP,query_val(QUERY_PARAM_SEASON));

    HTML_LOG(1,"Media types = [%s]",media_types);
    if (media_types) {
        add_op_clause(&val,0,media_types,CONTAINS_OP,DB_FLDID_CATEGORY FIELD_OP);
    }

    // Watched
    if (STRCMP(query_val(QUERY_PARAM_WATCHED_FILTER),QUERY_PARAM_WATCHED_VALUE_ANY) != 0) {
        add_op_clause(&val,0,DB_FLDID_WATCHED FIELD_OP,EQ_OP,query_val(QUERY_PARAM_WATCHED_FILTER));
    }

    // Locked
    if (STRCMP(query_val(QUERY_PARAM_LOCKED_FILTER),QUERY_PARAM_LOCKED_VALUE_ANY) != 0) {
        add_op_clause(&val,0,DB_FLDID_LOCKED FIELD_OP,EQ_OP,query_val(QUERY_PARAM_LOCKED_FILTER));
    }

    // Add first media type.
    ViewMode *v = get_view_mode(0);
    if (v == VIEW_TVBOXSET || v == VIEW_MOVIEBOXSET) {
        add_op_clause(&val,0,v->media_types,CONTAINS_OP,DB_FLDID_CATEGORY FIELD_OP);
    }

    // Title Filter
#define STRING_FN_CONTAINS 'c'
#define STRING_FN_STARTS 's'
#define STRING_FN_EQUALS 'e'
#define STRING_TYPE_STRING 's'
#define STRING_TYPE_REGEX 'r'
#define STRING_FUNCTION(s) \
        (((*s) == STRING_FN_CONTAINS || (*s) == STRING_FN_STARTS || (*s) == STRING_FN_EQUALS) && \
         (s[1] == STRING_TYPE_STRING || s[1] == STRING_TYPE_REGEX))

    char *title_pat = query_val(QUERY_PARAM_TITLE_FILTER);
    if (title_pat && *title_pat) {
        if (STRING_FUNCTION(title_pat)) {

            char op_text[10];

            char method = title_pat[0];
            char expType = title_pat[1];
            if (expType == QPARAM_FILTER_REGEX[0] ) {
                sprintf(op_text,"~%c%s~",method,QPARAM_FILTER_REGEX);
            } else if (expType == QPARAM_FILTER_STRING[0] ) {
                sprintf(op_text,"~%c~",method);
            } else {
                assert(0);
            }
            char *tmp;
            char *tmp2 = escape(title_pat+2,'\\',"'");
            ovs_asprintf(&tmp,"'%s'",tmp2);
            if (tmp2 != title_pat+2) {
                FREE(tmp2);
            }

            add_op_clause(&val,0,DB_FLDID_TITLE FIELD_OP, op_text , tmp );
            FREE(tmp);

        } else {
            add_op_clause(&val,0,DB_FLDID_TITLE FIELD_OP, "~"QPARAM_FILTER_STARTS_WITH"~" , title_pat );
        }
    }

    //Person
    char *person = query_val(QUERY_PARAM_PERSON);
    char *role = query_val(QUERY_PARAM_PERSON_ROLE);

    if (person && *person && role) {
        // CONTAINS_OP is used because the field value is a list.
        char *q;
        ovs_asprintf(&q,"%s" FIELD_OP CONTAINS_OP "%s",role,person);
        add_op_clause(&val,1,NULL,q,NULL);
        FREE(q);
    }

    // rating
    char *rating_str = query_val(QUERY_PARAM_RATING);
    if (rating_str && *rating_str) {
        char *hyphen = strchr(rating_str,'-');
        if (hyphen) {
            *hyphen='\0';
            add_op_clause(&val,0,DB_FLDID_RATING FIELD_OP,"~ge~",rating_str);
            add_op_clause(&val,0,DB_FLDID_RATING FIELD_OP,"~le~",hyphen+1);
            *hyphen='-';
        }
    }

    // General query
    char *query=query_val(QUERY_PARAM_QUERY);
    if(query && *query) {
        add_op_clause(&val,1,NULL,query,NULL);
    }
    
    if (val) {
        result = parse_full_url_expression(val,TOKEN_URL);
    }
    return result;

}

void add_op_clause(char **val,int allow_empty_parts,char *left,char *op,char *right)
{
    char *result = *val;
    if (allow_empty_parts || (left && *left && right && *right) ) {
        char *tmp;
        if (result == NULL) {
            // First clause
            ovs_asprintf(&tmp,"%s%s%s",NVL(left),op,NVL(right));
        } else {
            // Append clause
            ovs_asprintf(&tmp,"%s~a~(%s%s%s)",result,NVL(left),op,NVL(right));
        }
        result = tmp;
        HTML_LOG(0,"filter [%s]",result);
    } else {
        HTML_LOG(0,"skip clause [%s]%s[%s]",left,op,right);
    }
    *val = result;
}
