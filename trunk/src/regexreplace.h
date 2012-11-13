#ifndef REGEXREPLACE_H
#define REGEXREPLACE
#include <string.h>
#include <stdlib.h>
#include <regex.h>

#define MAX_NMATCH    10
typedef struct{
    int offset;
    regmatch_t pmatch[MAX_NMATCH];
} regmatch_tt;
/* Move a string into a string */
int s1(char* s, int sl, char* r, int rl){
    memmove(s+rl, s+sl, strlen(s)-sl+1);
    memcpy(s, r, rl);
    return rl-sl;    
}
/* Handle realloc */
int reallocx(char** x, int s, int max){
    char *tmp;
    if(s>max)
        return -1;
    if((tmp = realloc(*x, s))!=0){
        *x = tmp;
        return 0; 
    }
    else
        return -1; 
} 
/* Use regexec, but to match all occurrences */
int regexec_matchall(regex_t* pregx, const char* instring, size_t nmatch_t, regmatch_tt * pmatcht, int flags ){
    int offset, counter;
    offset = 0;
    counter = 0;
    while (regexec (pregx, instring+offset, MAX_NMATCH, pmatcht[counter].pmatch, REG_EXTENDED)==0 && counter<nmatch_t) {  /* While matches found. */
        pmatcht[counter].offset = offset;
        offset+= pmatcht[counter].pmatch[0].rm_eo;
        counter++;
    }
    while(counter<nmatch_t-1){
        pmatcht[counter].offset=-1;
        counter++;
    }
    if(offset == 0)
        return -1;
    else
        return 0;
}
/* The function that actually does the work */
int preg_replace(regex_t* pregxo, char* replacement,  regex_t*  pregx, char* tomatchx, char** out, int maxlength){

    int i,j,k, offset, offset2; 

    regmatch_tt pmatcht[MAX_NMATCH];
    regmatch_tt pmatchto[MAX_NMATCH];

    regmatch_tt* pt, *mt, *xt;
    regmatch_t * p,  *m,  *x;

    char    tmpvalue2[256];
    char    *c;
    char    *tomatch = 0;
    int    deltalen;
    char    *tmpreplacement = 0;

    if(reallocx(&tomatch, strlen(tomatchx)+1,maxlength)==-1)
        goto FINISHED;
    else
        strcpy(tomatch, tomatchx);


    if(regexec_matchall(pregxo, replacement, 10, pmatchto, 0)!=0){
    }
    if(regexec_matchall(pregx, tomatch, 10, pmatcht, 0)!=0){
        return -1;
    }

    offset=0;

    for(i = 0 ; i < MAX_NMATCH &&  pmatcht[i].offset!=-1; i++){
        if(reallocx(&tmpreplacement, strlen(replacement)+1,maxlength)==-1)
            goto FINISHED;
        else
            strcpy(tmpreplacement, replacement);
        offset2=0;

        for( k = 0 ;  k < MAX_NMATCH && pmatchto[k].offset !=-1 ;k ++){
            pt = &pmatchto[k];
            p = &pt->pmatch[0];
            
            memset(tmpvalue2, 0, 256);
            strncpy(tmpvalue2, &tmpreplacement[p->rm_so+pt->offset+offset2], p->rm_eo-p->rm_so);

            while((c=strchr(tmpvalue2, '\\'))!=0)
                *c='0';
            j = atoi(tmpvalue2);
            if(j< MAX_NMATCH && pmatcht[i].pmatch[j].rm_so !=-1 ){
                mt = &pmatcht[i];
                m = &mt->pmatch[j];
                deltalen=(m->rm_eo-m->rm_so)-(p->rm_eo-p->rm_so);
                if(deltalen>0 && reallocx(&tmpreplacement,strlen(tmpreplacement)+deltalen+1, maxlength)==-1)
                    goto FINISHED;
                offset2+=s1(&tmpreplacement[p->rm_so+pt->offset+offset2], p->rm_eo-p->rm_so, 
                        &tomatch[m->rm_so+mt->offset+offset], m->rm_eo-m->rm_so);
            }
            else{
                char* x ="";
                offset2+=s1(&tmpreplacement[p->rm_so+pt->offset+offset2], p->rm_eo-p->rm_so, x, 0);
            }
        }    
        xt = &pmatcht[i];
        x = &xt->pmatch[0];

        deltalen=(strlen(tmpreplacement)-(x->rm_eo-x->rm_so));
        if(deltalen> 0 && reallocx(&tomatch, strlen(tomatch)+deltalen+1,maxlength)==-1)
            goto FINISHED;
        offset+=s1(&tomatch[x->rm_so+xt->offset+offset], x->rm_eo-x->rm_so, tmpreplacement, strlen(tmpreplacement ) );
        free(tmpreplacement);
        tmpreplacement=0;

    }
    *out=tomatch;
    return 0;
FINISHED:
    if(tomatch)
        free(tomatch);
    if(tmpreplacement)
        free(tmpreplacement);
    return -1;
}
/* The regexec replace function */
int regexreplace(char * pattern, char* replacement, char* instring,  char** outstring, int maxlength){
    regex_t pregx, pregxo;
    int retvalue;
    const char* patterno = "\\(\\\\[0-9][0-9]*\\)";
    if(regcomp(&pregxo, patterno, 0)!=0){
        return -1; }
    if(regcomp(&pregx, pattern, 0)!=0){
        return -1; }
    retvalue=preg_replace(&pregxo, replacement,  &pregx, instring, outstring, maxlength);
    regfree(&pregxo);
    regfree(&pregx);
    return retvalue;
}
#endif
