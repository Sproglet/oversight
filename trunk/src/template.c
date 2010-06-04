/* (c) 2009 Andrew Lord - GPL V3 */
// $Id:$
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <errno.h>
#include <unistd.h>
#include <regex.h>
#include <time.h>
#include <ctype.h>

#include "template.h"
#include "gaya_cgi.h"
#include "util.h"
#include "macro.h"

/*
#include "array.h"
#include "dbplot.h"
#include "dboverview.h"
#include "oversight.h"
#include "hashtable.h"
#include "hashtable_loop.h"
#include "mount.h"
*/

// vi:sw=4:et:ts=4

char *scanlines_to_text(long scanlines);
char *template_replace_only(char *skin_name,char *orig_skin,char *input,int num_rows,DbRowId **sorted_row_ids);
int template_replace_and_emit(char *skin_name,char *orig_skin,char *input,int num_rows,DbRowId **sorted_row_ids);
int template_replace(char *skin_name,char *orig_skin,char *input,int num_rows,DbRowId **sorted_row_ids);

int display_template_file(char*skin_name,char *orig_skin,char *resolution,char *file_name,int num_rows,DbRowId **sorted_row_ids)
{

    int ret = 1;
    char *file_path;

    ovs_asprintf(&file_path,"%s/templates/%s/%s/%s.template",appDir(),
            skin_name,
            resolution,
            file_name);


    FILE *fp=fopen(file_path,"r");
    if (fp == NULL) {

        HTML_LOG(0,"Unable to open %s : error %d",file_path,errno);

    } else {
        // gaya has css bug. item after comments is ignored.
        int is_css = util_starts_with(file_name,"css.") ;
        int fix_css_bug = is_css && is_local_browser();

        char *dummy_css = "";

        if (fix_css_bug) {
            dummy_css = ".a {}\n";
        }

        if (strstr(file_path,"css")) {
            printf("/* Reading %s */%s\n",file_path,dummy_css);
        } else {
            HTML_LOG(0,"Reading %s",file_path);
        }
#define HTML_BUF_SIZE 999
        ret = 0;

        char buffer[HTML_BUF_SIZE];


        PRE_CHECK_FGETS(buffer,HTML_BUF_SIZE);
        while(fgets(buffer,HTML_BUF_SIZE,fp) != NULL) {
            CHECK_FGETS(buffer,HTML_BUF_SIZE);

            int count = 0; 
            char *p=buffer;
//            while(*p == ' ') {
//                p++;
//            }
            if ((count=template_replace(skin_name,orig_skin,p,num_rows,sorted_row_ids)) != 0 ) {
                HTML_LOG(4,"macro count %d",count);
            }

            if (fix_css_bug && strstr(p,"*/") ) {
                printf(dummy_css);
            }

        }
        fflush(stdout);
        fclose(fp);
    }

    if (file_path) FREE(file_path);
    HTML_LOG(1,"end template");
    return ret;
}

// 0 = success
int display_template(char*skin_name,char *file_name,int num_rows,DbRowId **sorted_row_ids)
{
    int ret = 0;

    HTML_LOG(1,"begin template");

    char *resolution = scanlines_to_text(g_dimension->scanlines);
    if (display_template_file(skin_name,skin_name,resolution,file_name,num_rows,sorted_row_ids) != 0) {
        if (display_template_file(skin_name,skin_name,"any",file_name,num_rows,sorted_row_ids) != 0) {
            if (display_template_file("default",skin_name,resolution,file_name,num_rows,sorted_row_ids) != 0) {
                if (display_template_file("default",skin_name,"any",file_name,num_rows,sorted_row_ids) != 0) {
                    html_error("failed to load template %s",file_name);
                    ret = 1;
                }
            }
        }
    }
    return ret;
}

#define MACRO_STR_START "["
#define MACRO_STR_END "]"
#define MACRO_STR_START_INNER ":"
#define MACRO_STR_END_INNER ":"
int template_replace(char *skin_name,char *orig_skin,char *input,int num_rows,DbRowId **sorted_row_ids)
{

TRACE;

    // first replace simple variables in the buffer.
    char *newline=template_replace_only(skin_name,orig_skin,input,num_rows,sorted_row_ids);
    if (newline != input) {
        HTML_LOG(2,"old line [%s]",input);
        HTML_LOG(2,"new line [%s]",newline);
    }
    // if replace complex variables and push to stdout. this is for more complex multi-line macros
    int count = template_replace_and_emit(skin_name,orig_skin,newline,num_rows,sorted_row_ids);
    if (newline !=input) FREE(newline);
    return count;
}

char *template_replace_only(char *skin_name,char *orig_skin,char *input,int num_rows,DbRowId **sorted_row_ids) {

TRACE;
    char *newline = input;
    char *macro_start = NULL;
    int count = 0;


    macro_start = strstr(input,MACRO_STR_START);
    while (macro_start ) {

        char *macro_name_start = NULL;
        char *macro_name_end = NULL;
        char *macro_end = NULL;

        // Check we have MACRO_STR_START .. MACRO_STR_START_INNER MACRO_NAME MACRO_STR_END_INNER .. MACRO_STR_END
        // eg [text1:name:text2]
        // If the macro "name" is non-empty then "text1 macro-out text2" is printed.
        macro_name_start=strstr(macro_start,MACRO_STR_START_INNER);
        if (macro_name_start) {
            macro_name_start++;
            macro_name_end = strstr(macro_name_start,MACRO_STR_END_INNER);
            if (macro_name_end) {
                macro_end=strstr(macro_name_end,MACRO_STR_END);
            }
        }

        // Cant identify macro - advance to next character.
        if (macro_name_start == NULL || macro_name_end == NULL || macro_end == NULL || *macro_name_start != '$'  ) {

            macro_end = macro_start;

        } else {

            int free_result=0;
            *macro_name_end = '\0';
            char *macro_output = macro_call(skin_name,orig_skin,macro_name_start,num_rows,sorted_row_ids,&free_result);
            count++;
            *macro_name_end = *MACRO_STR_START_INNER;
            if (macro_output) {


                //convert AA[BB:$CC:DD]EE to AABBnewDDEE

                *macro_start = '\0';   //terminate AA
                 macro_name_start[-1] = '\0';  // terminate BB
                 *macro_end = '\0'; // terminate DD

                 char *tmp;

                 ovs_asprintf(&tmp,"%s%s%s%s%s",newline,macro_start+1,macro_output,macro_name_end+1,macro_end+1);

                 // Adjust the end pointer so it is relative to the new buffer.
                 char *new_macro_end = tmp + strlen(newline)+strlen(macro_start+1)+strlen(macro_output)+strlen(macro_name_end+1);
                 
                 // put back the characters we just nulled.
                 *macro_start = *MACRO_STR_START;
                 macro_name_start[-1] = *MACRO_STR_START_INNER;
                 *macro_end = *MACRO_STR_END;

                 if (free_result) FREE(macro_output);
                 if (newline != input) FREE(newline);
                 newline = tmp;

                 macro_end = new_macro_end;
            } else {
                //convert AA[BB:$CC:DD]EE to AAEE
                char *p=macro_end+1;
                int i = strlen(p)+1;
                memmove(macro_start+1,p,i);
                macro_end = macro_start;

             }
        }

        macro_start=strstr(++macro_end,MACRO_STR_START);

    }
    return newline;
}
int template_replace_and_emit(char *skin_name,char *orig_skin,char *input,int num_rows,DbRowId **sorted_row_ids) {

TRACE;
    char *macro_start = NULL;
    int count = 0;


    char *p = input;
    while(isspace(*p)) {
        p++;
    }
    macro_start = strstr(p,MACRO_STR_START);
    while (macro_start ) {

        char *macro_name_start = NULL;
        char *macro_name_end = NULL;
        char *macro_end = NULL;

        // Check we have MACRO_STR_START .. MACRO_STR_START_INNER MACRO_NAME MACRO_STR_END_INNER .. MACRO_STR_END
        // eg [text1:name:text2]
        // If the macro "name" is non-empty then "text1 macro-out text2" is printed.
        macro_name_start=strstr(macro_start,MACRO_STR_START_INNER);
        if (macro_name_start) {
            macro_name_start++;
            macro_name_end = strstr(macro_name_start,MACRO_STR_END_INNER);
            if (macro_name_end) {
                macro_end=strstr(macro_name_end,MACRO_STR_END);
            }
        }

        // Cant identify macro - advance to next character.
        if (macro_name_start == NULL || macro_name_end == NULL || macro_end == NULL  ) {

            //emit stuff before macro - this is done as late as possible so HTML_LOG in macro doesnt interrupt tag flow
            if (output_state() ) {
                PRINTSPAN(p,macro_start);
                putc(*MACRO_STR_START,stdout);
            }
            macro_end = macro_start;

        } else {

            int free_result=0;
            *macro_name_end = '\0';
            char *macro_output = macro_call(skin_name,orig_skin,macro_name_start,num_rows,sorted_row_ids,&free_result);

            //emit stuff before macro - this is done as late as possible so HTML_LOG in macro doesnt interrupt tag flow
            if (macro_start > p ) {
                if (output_state() ) {
                    printf("%.*s",macro_start-p,p); 
                }
            }

            count++;
            *macro_name_end = *MACRO_STR_START_INNER;
            if (macro_output && *macro_output) {

                 if (output_state() ) {
                     // Print bit before macro call
                     PRINTSPAN(macro_start+1,macro_name_start-1);
                     fflush(stdout);

                     printf("%s",macro_output);
                     fflush(stdout);

                     // Print bit after macro call
                     PRINTSPAN(macro_name_end+1,macro_end);
                     fflush(stdout);
                 }
                 if (free_result) FREE(macro_output);
             }
        }

        p=macro_end+1;

        macro_start=strstr(p,MACRO_STR_START);

    }

    if (output_state() ) {
        // Print the last bit
        printf("%s",p);
        fflush(stdout);
    }
TRACE;
    return count;
}

char *scanlines_to_text(long scanlines)
{
    switch(scanlines) {
        case 1080: return "1080";
        case 720: return "720";
        default: return "sd";
    }
}

char *skin_name()
{
    static char *template_name=NULL;
    if (!template_name) template_name=oversight_val("ovs_skin_name");
    return template_name;
}

// Get an icon file from the root folder. Fall back to default folder if it doesnt exist.
char *icon_source(char *image_name) {
    return image_source("",image_name,NULL);
}

// Get an image file  templates/skin/images/subfolder/name.ext . Fall back to
// templates/default/images/subfolder/name.exe if it doesnt exist.
// returns a quoted url.
char *image_source(char *subfolder,char *image_name,char *ext)
{
    assert(image_name);
    static char *ico=NULL;
    
    if (ext == NULL) {
        if (ico == NULL) ico = ovs_icon_type();
        ext = ico;
    }
    char *image_folder=NULL;
    ovs_asprintf(&image_folder,"images%s%s",(EMPTY_STR(subfolder)?"":"/"),NVL(subfolder));

    char *result =  file_source(image_folder,image_name,ext);
    FREE(image_folder);

    return result;
}

char *file_source(char *subfolder,char *image_name,char *ext)
{

    char *path;

    static int is_default_skin = UNSET;
    if (is_default_skin == UNSET) {
        is_default_skin = (STRCMP(skin_name(),"default") == 0);
    }

    if (subfolder == NULL) {
        subfolder = "";
    }

    ovs_asprintf(&path,"%s/templates/%s%s%s/%s%s%s",
            appDir(),
            skin_name(),
            (EMPTY_STR(subfolder)?"":"/"),
            NVL(subfolder),
            image_name,
            (EMPTY_STR(ext)?"":"."),
            ext);

    if (!exists(path) && !is_default_skin) {
        HTML_LOG(0,"[%s] not found",path);
        FREE(path);

        ovs_asprintf(&path,"%s/templates/default%s%s/%s%s%s",
                appDir(),
                (EMPTY_STR(subfolder)?"":"/"),
                NVL(subfolder),
                image_name,
                (EMPTY_STR(ext)?"":"."),
                ext);
    }

    char *result = file_to_url(path);
    FREE(path);
    return result;
}

