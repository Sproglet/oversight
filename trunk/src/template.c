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
//
// TODO:
// Rewrite code to use TemplateFramgents
// Pass0: template file is loaded into memory - each line is a fragment in a doubly linked list.
// Pass1: Call macros. Each non-NULL macro result inserts a new fragment
// Pass2: Repeat  (now PAGE_MAX macro will work)
// Output: Output all fragments in sequence.
//

char *scanlines_to_text(long scanlines);
char *template_line_replace_only(int pass,char *skin_name,char *orig_skin,char *input,DbSortedRows *sorted_rows,int *has_macro_ptr,FILE *out);
int template_line_replace_and_emit(int pass,char *skin_name,char *orig_skin,char *input,DbSortedRows *sorted_rows,int *has_macro_ptr,FILE *out);
int template_line_replace(int pass,char *skin_name,char *orig_skin,char *input,DbSortedRows *sorted_rows,FILE *out);

int display_template_file(int pass,FILE *in,char*skin_name,char *orig_skin,char *resolution,char *file_name,DbSortedRows *sorted_rows,FILE *out)
{

    int ret = 1;

    if (in == NULL) {

        HTML_LOG(1,"Unable to open template : error %d",errno);

    } else {
        // gaya has css bug. item after comments is ignored.
        int is_css = util_starts_with(file_name,"css.") ;
        int fix_css_bug = is_css && is_local_browser();

        char *dummy_css = "";

        if (fix_css_bug) {
            dummy_css = ".a {}\n";
        }

#define HTML_BUF_SIZE 5999
        ret = 0;

        char buffer[HTML_BUF_SIZE];


        /*
         * Read and process lines. if lines have formt [LOOP_START:]..[:LOOP_END:] then add to hashtable(skin_name,file_name,loop_name)
         * For later processing by [:LOOP_EXPAND(name,start,end,increment):]
         */
        Array *loop_body=NULL;
        PRE_CHECK_FGETS(buffer,HTML_BUF_SIZE);
        while(fgets(buffer,HTML_BUF_SIZE,in) != NULL) {
            CHECK_FGETS(buffer,HTML_BUF_SIZE);

            if (loop_body) {
                if (util_starts_with(buffer,"[:LOOP_END:]")) {
                    loop_body = NULL;
                } else {
                    // Add to loop body
                    //HTML_LOG(0,"loop[%s]",buffer);
                    array_add(loop_body,STRDUP(buffer));
                }
            } else {

                if (util_starts_with(buffer,"[:LOOP_START")) {
                    char *loop_name=regextract1(buffer,":LOOP_START\\(name=>([^)]+)\\):",1,0);
                    if (loop_name) {
                        HTML_LOG(0,"loop[%s]",loop_name);
                        loop_body = loop_register(loop_name);
                        FREE(loop_name);
                    } else {
                        html_error("failed to parse loop line [%s]",buffer);
                    }
                } else {

                    // A normal line outside of a loop

                    int count = 0; 
                    char *p=buffer;
        //            while(*p == ' ') {
        //                p++;
        //            }
                    if ((count=template_line_replace(pass,skin_name,orig_skin,p,sorted_rows,out)) != 0 ) {
                        HTML_LOG(4,"macro count %d",count);
                    }

                    if (fix_css_bug && strstr(p,"*/") ) {
                        printf(dummy_css);
                    }
                }
            }

        }
        fflush(out);
    }

    HTML_LOG(1,"end template");
    return ret;
}

char *get_template_path(char *skin_name,char *file_name)
{
    char *path=NULL;

    char *resolution = scanlines_to_text(g_dimension->scanlines);

    char *skin[] = { skin_name , "default" , NULL };
    char *res[] = { resolution , "any" , NULL };
    int s;
    int r;

    for(s = 0 ; skin[s] && !path ; s++ ) {
        for (r = 0 ; res[r] && !path ; r++ ) {
            ovs_asprintf(&path,"%s/templates/%s/%s/%s.template",appDir(),skin[s],res[r],file_name);

            if (exists(path)) {
                if (strstr(file_name,"css")) {
                    html_set_comment("/* ","*/ .a {};");
                }
                HTML_LOG(0,"Reading %s",path);
                break;
            }
            FREE(path);
            path = NULL;
        }
    }


    return path;
}

/*
 * return NULL=ok else error message
 */
char *end_pass1() 
{
    char *error_text = NULL;
    error_text = grid_calculate_offsets(get_grid_info());
    return error_text;
}

int display_main_template(char *skin_name,char *file_name,DbSortedRows *sorted_rows)
{
    int ret = -1;
    int pass=0;
    
    //
    //This is done in two passes so we know how many items will eventually be displayed at any point on the page.
    //This is required for  [:PAGE_MAX:]  and [:RIGHT:] macros for example.

    //char *pass1_file = "/tmp/ovs1";
    char *pass1_file = "/share/ovs1";
    FILE *pass1_fp = NULL;
   
    pass1_fp = fopen(pass1_file,"w");

    if (pass1_fp) {
        HTML_LOG(0,"output to %s",pass1_file);
        html_set_output(pass1_fp);
        HTML_LOG(0,"begin pass1 [%s]",pass1_file);
        ret = display_template(++pass,NULL,skin_name,file_name,sorted_rows,pass1_fp);
        HTML_LOG(0,"end pass1");
        fclose(pass1_fp);
        html_set_output(stdout);

        if (ret == 0) {

            char *error_text = end_pass1();
            if (error_text) {
                HTML_LOG(0,"pass1 error [ %s ]",error_text);
                ret = -1 ;
            }
        }

        if (ret == 0) {
            pass1_fp = fopen(pass1_file,"r");
            FILE *pass2_fp = stdout;
            if (pass1_fp) {
                HTML_LOG(0,"output to stdout");
                html_set_output(pass2_fp);
                HTML_LOG(0,"begin pass2");
                ret = display_template(++pass,pass1_fp,skin_name,file_name,sorted_rows,pass2_fp);
                HTML_LOG(0,"end pass2");
                fclose(pass1_fp);
            }
        }
        unlink(pass1_file);
    }
    loop_deregister_all();

    return ret;

}

// 0 = success
int display_template(int pass,FILE *in,char*skin_name,char *file_name,DbSortedRows *sorted_rows,FILE *out)
{
    int ret = -1;

    char *path = NULL;

    html_set_output(out);
    char *resolution = scanlines_to_text(g_dimension->scanlines);

    html_set_comment("<!-- ","-->");
    if (in == NULL) {
        path = get_template_path(skin_name,file_name);
        if (path != NULL) {
            in = fopen(path,"r");
        }
        if (in == NULL) {
            html_error("failed to load template %s",file_name);
        }

    }
    if (in) {
        ret = display_template_file(pass,in,skin_name,skin_name,resolution,file_name,sorted_rows,out);
        if (path) {
            fclose(in);
        }
    }
    html_set_comment("<!-- ","-->");


    FREE(path);

    return ret;
}

#define MACRO_STR_START "["
#define MACRO_STR_END "]"
#define MACRO_STR_START_INNER ":"
#define MACRO_STR_END_INNER ":"
int template_line_replace(int pass,char *skin_name,char *orig_skin,char *input,DbSortedRows *sorted_rows,FILE *out)
{

TRACE;

    int has_macro = 0;


    // first replace simple variables in the buffer.
    char *newline=template_line_replace_only(pass,skin_name,orig_skin,input,sorted_rows,&has_macro,out);

    if (newline != input) {
        HTML_LOG(2,"old line [%s]",input);
        HTML_LOG(2,"new line [%s]",newline);
    }
    // if replace complex variables and push to stdout. this is for more complex multi-line macros
    int count = template_line_replace_and_emit(pass,skin_name,orig_skin,newline,sorted_rows,&has_macro,out);
    if (newline !=input) FREE(newline);
    return count;
}

int replace_macro(char *macro_name) {

    int result = 0;
    if (output_state()) {
        result = 1;
    } else if (util_starts_with(macro_name,"IF")
            || util_starts_with(macro_name,"ELSEIF")
            || util_starts_with(macro_name,"ELSE")
            || util_starts_with(macro_name,"ENDIF")
            || util_starts_with(macro_name,"LOOP_")
            ) {
        result = 1;
    }
    return result;
}


char *template_line_replace_only(int pass,char *skin_name,char *orig_skin,char *input,DbSortedRows *sorted_rows,int *has_macro_ptr,FILE *out)
{

TRACE;
    char *newline = input;
    char *macro_start = NULL;

    macro_start = strstr(input,MACRO_STR_START);
    while (macro_start ) {

        (*has_macro_ptr)++;
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

        } else if (!replace_macro(macro_name_start)) {

            macro_end = macro_start;

        } else {

            int free_result=0;
            *macro_name_end = '\0';

            char *macro_output = macro_call(pass,skin_name,orig_skin,macro_name_start,sorted_rows,&free_result,out);
            *macro_name_end = *MACRO_STR_START_INNER;

            if (macro_output == CALL_UNCHANGED ) {
                // unchanged - do nothing
                
            } else if (!EMPTY_STR(macro_output)) {

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

                 if (free_result && macro_output != CALL_UNCHANGED) FREE(macro_output);
                 if (newline != input) FREE(newline);
                 newline = tmp;

                 macro_end = new_macro_end;
            } else {
                //convert AA[BB:$CC:DD]EE to AAEE
                char *p=macro_end+1;
                int i = strlen(p)+1;
                memmove(macro_start,p,i);
                macro_end = macro_start;

             }
        }

        macro_start=strstr(++macro_end,MACRO_STR_START);

    }
    return newline;
}

int template_line_replace_and_emit(int pass,char *skin_name,char *orig_skin,char *input,DbSortedRows *sorted_rows,int *has_macro_ptr,FILE *out)
{

TRACE;
    char *macro_start = NULL;
    int count = 0;
    int flush = 0;

    char *p = input;

    if (*has_macro_ptr) {
        while(isspace(*(unsigned char *)p)) {
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
                    FPRINTSPAN(out,p,macro_start);
                    fputc(*MACRO_STR_START,out);
                }
                macro_end = macro_start;

            } else if (!replace_macro(macro_name_start)) {

                //emit stuff before macro - this is done as late as possible so HTML_LOG in macro doesnt interrupt tag flow
                if (output_state() ) {
                    FPRINTSPAN(out,p,macro_start);
                    fputc(*MACRO_STR_START,out);
                }
                macro_end = macro_start;

            } else {

                int free_result=0;
                *macro_name_end = '\0';
                char *macro_output = macro_call(pass,skin_name,orig_skin,macro_name_start,sorted_rows,&free_result,out);

                //emit stuff before macro - this is done as late as possible so HTML_LOG in macro doesnt interrupt tag flow
                if (macro_start > p ) {
                    if (output_state() ) {
                        fprintf(out,"%.*s",macro_start-p,p); 
                    }
                }

                count++;
                *macro_name_end = *MACRO_STR_START_INNER;
                if (macro_output ) {

                     if (output_state() ) {

                        if (macro_output == CALL_UNCHANGED ) {

                            // unchanged.
                            FPRINTSPAN(out,macro_start,macro_end+strlen(MACRO_STR_END));

                        } else {
                            // Print bit before macro call
                            FPRINTSPAN(out,macro_start+1,macro_name_start-1);

                            fputs(macro_output,out);

                            // Print bit after macro call
                            FPRINTSPAN(out,macro_name_end+1,macro_end);
                        }

                         flush++;

                     }
                     if (free_result && (macro_output != CALL_UNCHANGED)) FREE(macro_output);
                 }
            }

            p=macro_end+1;

            macro_start=strstr(p,MACRO_STR_START);

        }
    }

    if (output_state() ) {
        // Print the last bit
        fputs(p,out);
        flush++;
    }
    if (flush) {
        fflush(out);
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

char *get_skin_name() {
#if 1
    char *skin_name=query_val(QUERY_PARAM_SKIN_NAME);

    if (EMPTY_STR(skin_name)) {
#if 0
        if (g_dimension && !g_dimension->local_browser) {
            skin_name=oversight_val("ovs_remote_skin_name");
        }
#endif
        if (EMPTY_STR(skin_name)) {
            skin_name=oversight_val("ovs_skin_name");
        }
    }
#else
    char *skin_name=oversight_val("ovs_skin_name");
#endif
    return skin_name;
}

char *skin_path()
{
    static char *path = NULL;
    if (path == NULL) {
        ovs_asprintf(&path,"%s/templates/%s",appDir(),get_skin_name());
    }
    return path;
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
    char *result = NULL;

    if (!image_name) {
        HTML_LOG(0,"empty image_name subfolder[%s]",subfolder);
    } else {

        static char *ico=NULL;
        
        if (ext == NULL) {
            if (ico == NULL) ico = ovs_icon_type();
            ext = ico;
        }
        char *image_folder=NULL;
        ovs_asprintf(&image_folder,"images%s%s",(EMPTY_STR(subfolder)?"":"/"),NVL(subfolder));

        result =  file_source(image_folder,image_name,ext);
        FREE(image_folder);
    }

    return result;
}

char *file_source(char *subfolder,char *image_name,char *ext)
{

    char *path;

    static int is_default_skin = UNSET;
    if (is_default_skin == UNSET) {
        is_default_skin = (STRCMP(get_skin_name(),"default") == 0);
    }

    if (subfolder == NULL) {
        subfolder = "";
    }

    ovs_asprintf(&path,"%s/templates/%s%s%s/%s%s%s",
            appDir(),
            get_skin_name(),
            (EMPTY_STR(subfolder)?"":"/"),
            NVL(subfolder),
            image_name,
            (EMPTY_STR(ext)?"":"."),
            ext);

    if (!exists(path)) {

        if (is_default_skin) {
            HTML_LOG(0,"[%s] not found",path);
        }
        FREE(path);

        ovs_asprintf(&path,"%s/templates/default%s%s/%s%s%s",
                appDir(),
                (EMPTY_STR(subfolder)?"":"/"),
                NVL(subfolder),
                image_name,
                (EMPTY_STR(ext)?"":"."),
                ext);
        if (!exists(path)) {
            FREE(path);
            path = NULL;
        }
    }

    char *result = file_to_url(path);
    FREE(path);
    return result;
}


