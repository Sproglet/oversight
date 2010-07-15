#ifndef __OVS_EXP_H__
#define __OVS_EXP_H__

typedef enum Op_enum {
    OP_VALUE=0,
    OP_ADD='+',
    OP_SUBTRACT='-',
    OP_MULTIPLY='*',
    OP_DIVIDE='/',
    OP_AND='&',
    OP_OR='O',
    OP_NOT='!',
    OP_EQ='=',
    OP_NE='~',
    OP_LE='{',
    OP_LT='<',
    OP_GT='>',
    OP_GE='}',
    OP_STARTS_WITH='^',
    OP_CONTAINS='#',
    OP_DBFIELD='_'
} Op;

typedef enum ValType_enum {
    VAL_TYPE_NUM='i',
    VAL_TYPE_STR='s'
} ValType;

typedef struct Value_struct {
    ValType type;
    double num_val;
    char *str_val;
    int free_str;

} Value;

typedef struct Exp_struct {

    Op op;
    struct Exp_struct *subexp[2];
    Value val;
} Exp;

void exp_test();

#endif
