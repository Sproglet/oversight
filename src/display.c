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

#include "display.h"
#include "gaya_cgi.h"
#include "util.h"
#include "array.h"
#include "db.h"
#include "dbplot.h"
#include "dboverview.h"
#include "oversight.h"
#include "hashtable.h"
#include "hashtable_loop.h"
#include "macro.h"
#include "mount.h"
    
// When user drills down to a new view, there are some navigation html parameters p (page) and idlist and view.
// The old values are prefixed with @ before adding new ones.
#define DRILLDOWN_CHAR '@'
#define DRILL_DOWN_PARAM_NAMES QUERY_PARAM_SELECTED","QUERY_PARAM_PAGE","QUERY_PARAM_IDLIST","QUERY_PARAM_VIEW"," QUERY_PARAM_REGEX "," QUERY_PARAM_SEASON

#define JAVASCRIPT_EPINFO_FUNCTION_PREFIX "tvinf_"
#define JAVASCRIPT_MENU_FUNCTION_PREFIX "t_"

char *get_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr);
char *get_theme_image_tag(char *image_name,char *attr);
char *icon_source(char *image_name);
void util_free_char_array(int size,char **a);
char *get_date_static(DbRowId *rid);
DbRowId **filter_delisted(int start,int num_rows,DbRowId **row_ids,int max_new,int *new_num);
char *get_drilldown_view(DbRowId *rid);
char *get_final_link_with_font(char *params,char *attr,char *title,char *font_attr);
static char *get_drilldown_name(char *root_name,int num_prefix);
char *remove_blank_params(char *input);
void get_watched_counts(DbRowId *rid,int *watchedp,int *unwatchedp);
char *get_tv_drilldown_link(char *view,char *name,int season,char *attr,char *title,char *font_class,char *cell_no_txt);
char *get_tvboxset_drilldown_link(char *view,char *name,char *attr,char *title,char *font_class,char *cell_no_txt);
char *get_movie_drilldown_link(char *view,char *idlist,char *attr,char *title,char *font_class,char *cell_no_txt);

char *get_play_tvid(char *text) {
    char *result;
    ovs_asprintf(&result,
        "<a href=\"file://" NMT_PLAYLIST "?start_url=\" vod=playlist tvid=\"_PLAY\">%s</a>",text);
    return result;
}

// Return a full path 
char *get_path(DbRowId *rid,char *path,int *freepath) {

TRACE;

    *freepath = 0;
    char *mounted_path=NULL;

    char *path_relative_to_host_nmt=NULL;

    assert(path);
    if (path[0] == '/' ) {

        path_relative_to_host_nmt = path;

    } else if (util_starts_with(path,"ovs:")) {

        ovs_asprintf(&path_relative_to_host_nmt,"%s/db/global/%s",appDir(),path+4);
        *freepath = 1;

    } else {

        char *d=util_dirname(rid->file);
       ovs_asprintf(&path_relative_to_host_nmt,"%s/%s",d,path);
       FREE(d);
       *freepath = 1;
    }

    int free2;
    mounted_path=get_mounted_path(rid->db->source,path_relative_to_host_nmt,&free2);
TRACE;
    if (free2) {
        *freepath = 1;
    }
TRACE;

    // Free intermediate result if necessary
    if (path_relative_to_host_nmt != path && path_relative_to_host_nmt != mounted_path) {
        FREE(path_relative_to_host_nmt);
    }
TRACE;

    return mounted_path;
}







#define XHTML
void tag(char *label,char *attr,va_list ap) {

#ifdef XHTML
    static int count = 0;
    static char *stack[50];
#endif

    if (attr == NULL) {
        printf("</%s>\n",label);
#ifdef XHTML
        count --;
        if (count >= 0) {
            FREE(stack[count]);
        } else {
            html_error("empty html stack for </%s>",label);
        }
#endif
    } else {
        
#ifdef XHTML
        if (count && strcmp(label,stack[count]) == 0) {
            html_error("double nested <%s>",label); // div ok really
        }
#endif

        if (*attr == '\0') {
            printf("<%s>\n",label);
        } else {
            printf("<%s ",label);
            vprintf(attr,ap);
            printf(" >");
        }

#ifdef XHTML
        stack[count++] = STRDUP(label);
#endif
    }
}

void td(char *attr,...) {
    va_list ap;
    va_start(ap,attr);
    tag("td",attr,ap);
    va_end(ap);
}

// This used to be just "" but when replacing wget we need to send the full path
char *cgi_url(int full) {
    char *url = NULL;
    //HTML_LOG(0,"local_browser = [%d]",g_dimension->local_browser);
    if (g_dimension->local_browser || full) {
        url = getenv("SCRIPT_NAME");
        //HTML_LOG(0,"cgi_url = SCRIPT_NAME = [%s]",url);
    } else {
        url = "";
        //HTML_LOG(0,"cgi_url = [%s]",url);
    }
    return url;
}

// Merge the current query string with the parameters.
// Keep the parameters that are not in the new parameter list and are also not blank
// Also exclude "colour" because it represents a one off action and not at state.
#define MAX_PARAMS 50
char *self_url(char *new_params) {

    struct hashtable_itr *itr;
    char *param_name;
    char *param_value;

#define QSELFURL
#ifdef QSELFURL
    // Store params here.
    int pcount=0;
    int psize=0;
    char *pname[MAX_PARAMS];
    char *pval[MAX_PARAMS];
#else
    char *old_params = NULL;
    int first=1;
#endif

    // Cycle through each of the existing parameters
    for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&param_name,&param_value) ; ) {

        if (!EMPTY_STR(param_value)) {

            // Ignore parameters colour  option_* and orig_option_*

            if (param_name[0] == 'c' && strcmp(param_name,"colour") == 0) {
                // ignore
            } else if (param_name[0] == 'o' && 
                   (  util_starts_with(param_name,"option_" ) || util_starts_with(param_name,"orig_option_" ) ) ) {
                // ignore
            } else {
                //
                // search for pram_name in new_params

                // If the existing parameter name is also in the new parameter list then dont add it
                if (EMPTY_STR(new_params) || !delimited_substring(new_params,"&",param_name,"&=",1,1)) {

                    // Keep the old parameter
#ifdef QSELFURL
                    pname[pcount] = param_name;
                    pval[pcount] = param_value;
                    pcount++;
                    assert(pcount < MAX_PARAMS);
                    psize += strlen(param_name) + strlen(param_value) + 3;
#else

                    char *new;
                    ovs_asprintf(&new,"%s%c%s=%s",NVL(old_params),(first?'?':'&'),param_name,param_value);
                    FREE(old_params);
                    old_params = new;
                    first=0;
#endif
                }
            }
        }
    }

    char *tmp;
#ifdef QSELFURL
    char *new=MALLOC(strlen(cgi_url(0))+psize+strlen(new_params) + 3);
    tmp = new;
    tmp += sprintf(tmp,"%s",cgi_url(0));
    int i;
    for(i = 0 ; i < pcount ; i ++ ) {
        tmp += sprintf(tmp,"%c%s=%s",(i==0?'?':'&'),pname[i],pval[i]);
    }
    tmp += sprintf(tmp,"%c%s",(pcount==0?'?':'&'),new_params);
#else

    char *new;
    ovs_asprintf(&tmp,"%s%s%c%s",cgi_url(0),NVL(old_params),(first?'?':'&'),new_params);
    FREE(old_params);
    new = tmp;
#endif

    tmp = remove_blank_params(new);
    FREE(new);
    new = tmp;

    return new;
}

char *remove_blank_params(char *input)
{
    char *in = input;
    char *p;
    char *out = STRDUP(in);
    p = out;
    for(;;) {
        *p = *in;
        if ( ( *p == '\0' || *p == '&' ) && ( p[-1] == '=' ) ) {
            //HTML_LOG(0,"removing from [%.*s]",p-out,out);
            // We have xxx=& rewind to end of previous parameter.
            p--;
            while ( p>out &&  *p != '&' && *p != '?' ) {
                p--;
            }
            // now we are at the start or at the previous &
            if (*p == '&' || *p == '?' ) p++;
            *p = '\0'; // terminate to be on th safe side.
            //HTML_LOG(0,"removed from [%.*s]",p-out,out);
        } else {
            p++;
        }
        if (*in == '\0') break;
        in++;
    }
    if (0 && strcmp(input,out) != 0) {
        HTML_LOG(0,"remove_blank_params[%s] vs [%s]",input,out);
    }
    return out;
}


/*
 * True if param_name ~ ^DRILLDOWN_CHAR*root$
 * eg. @@@p is_drilldown_of p
 * @returns 0(no match) , 1=exact match , else 1+number of DRILLDOWN_CHAR
 */

int is_drilldown_of(char *param_name,char *root_name) 
{
    int result=0;
    char *p=param_name;
    while (*p && *p == DRILLDOWN_CHAR ) {
        p++;
    }
    if ( strcmp(p,root_name) ==0 ) {
        result = (p-param_name)+1;
    }
    //HTML_LOG(0,"is_drilldown_of(%s,%s)=%d",param_name,root_name,result);
    return result;
}

static char *self_url2(char *q1,char *q2)
{

    int free_full=0;
    char *full_query_string = NULL;
    /**
     * Now append the drilldown parameters to the actual parameters for this link
     * It is expected that the actual parameters will not contain drilldown @ parameters.
     */
    if (!EMPTY_STR(q1)) {
        if (EMPTY_STR(q2)) {
            full_query_string = q1;
        } else {
            free_full=1;
            ovs_asprintf(&full_query_string,"%s&%s",q1,q2);
        }
    } else {
        full_query_string = q2;
    }

TRACE;
    char *result = self_url(full_query_string);
TRACE;
    if (free_full) {
TRACE;
        FREE(full_query_string);
TRACE;
    }
TRACE;

    return result;
}
/*
 * 'new_params = query string selgment - ie p=1&q=2"
 * @param_list = list of parameters whose old values are kept in the url.
 *
 * eg given
 *
 * 'p=1 & @p=2 & @@p = 3
 *
 * '@p=1 & @@p=2 & @@@p = 3   
 *
 */
char *drill_down_url(char *new_params,char *param_list) 
{
    /*
     * for each parameter name pname in param list
     *    for each param Q in g_query do
     *       if Q.name matches ^@*(pname)$  eg , (pname) , @(pname) , @@(pname) etc.
     *          add @(Q.name)=(Q.value) to new parameter list.
     *       end if 
     *    end for
     * end for
     */

    char *new_drilldown_params = NULL;
    Array *drilldown_root_names=split(param_list,",",0);
    int i;
    if (drilldown_root_names) {
        for(i = 0 ; i < drilldown_root_names-> size ; i++ ) {
            char *param_name = drilldown_root_names->array[i];
            if (param_name) {
                struct hashtable_itr *itr;
                char *qname;
                char *qval;
                int min_depth = 0; // we need to track the item with fewest DRILLDOWN_CHAR and remove it


                for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&qname,&qval) ; ) {
                    int depth = is_drilldown_of(qname,param_name);
                    if (depth) {
                        char *tmp;
                        if (new_drilldown_params == NULL) {
                            ovs_asprintf(&new_drilldown_params,"%c%s=%s",DRILLDOWN_CHAR,qname,qval);
                        } else {
                            ovs_asprintf(&tmp,"%s&%c%s=%s",new_drilldown_params,DRILLDOWN_CHAR,qname,qval);
                            FREE(new_drilldown_params);
                            new_drilldown_params = tmp;
                        }

                        // track item with fewest DRILLDOWN_CHAR
                        if (depth < min_depth || min_depth == 0 ) {
                            min_depth = depth;
                        }
                    }
                }
                // Find item with fewest prefix. If it is not in the new_params then remove it
                if (min_depth) {
                    char *top_name = get_drilldown_name(param_name,min_depth-1);

                    if (!delimited_substring(new_params,"&",top_name,"&=",1,1)) {
                        char *tmp;
                        ovs_asprintf(&tmp,"%s&%s=",new_drilldown_params,top_name);
                        FREE(new_drilldown_params);
                        new_drilldown_params = tmp;
                    }

                    FREE(top_name);
                }
            }
        }
    }
    array_free(drilldown_root_names);

    /*
     * Compute the new url
     */
    char *final = self_url2(new_params,new_drilldown_params);

    FREE(new_drilldown_params);

    return final;
}

// this is a query string where existing @p,@view,@idlist parameters are moved back to
// p,view,idlist // so that we can return the the previous screen.
char *return_query_string() 
{

    /*
     * given parameter name p we want
     * p=1&@p=2&@@p=3 to become p=2&@p=3
     *
     * for each parameter pname in param list
     *    for each param Q in g_query do
     *       if Q.name = pname 
     *          if @name not in query then
     *             add Q.name=<blank>
     *          endif
     *       else if Q matches ^@+param$  eg , @param , @@param etc.
     *          add (Q.name)=((@Q).value) to new parameter list.
     *       end if 
     *    end for
     * end for
     *
 * e.g
 * '@p=1 & @@p=2 & @@@p = 3  
 *
 * becomes
 *
 * 'p=1 & @p=2 & @@p = 3
     */
    static Array *drilldown_root_names= NULL;
    if (drilldown_root_names == NULL ) {
        drilldown_root_names = split(DRILL_DOWN_PARAM_NAMES,",",0);
    }

    Array *new_drilldown_params = array_new(free);

    int i;
    if (drilldown_root_names) {
        for(i = 0 ; i < drilldown_root_names-> size ; i++ ) {
            char *param_name = drilldown_root_names->array[i];

            if (param_name) {
                struct hashtable_itr *itr;
                char *qname;
                char *qval;

                int max_depth = 0; // track the deepest level parameter to remove it

                for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&qname,&qval) ; ) {

                    int depth = is_drilldown_of(qname,param_name);

                    if (depth > 1) {
                        char *tmp;

                        char *new_name = qname + 1;

                        ovs_asprintf(&tmp,"&%s=%s",new_name,qval);
                        array_add(new_drilldown_params,tmp);

                    }
                    if (depth > max_depth ) {
                        max_depth = depth;
                    }
                }
                // Now remove the deepest eg.
                // if p=1&@p=2&@@p=3 becomes p=2&@p=3 we need to add @@p=
                if (max_depth > 0 ) {
                    int num_prefix = max_depth - 1;
                    char *last_name = get_drilldown_name(param_name,num_prefix);

                    char *tmp;
                    ovs_asprintf(&tmp,"&%s=",last_name);
                    array_add(new_drilldown_params,tmp);
                }



            }
        }
    }
    char *result = arraystr(new_drilldown_params);
    FREE(new_drilldown_params);
    return result;
}

// Compute url to go back to previous link.
char *return_url() {
    /*
     * Compute the new url
     */
    char *tmp = return_query_string();
    char *final = self_url(tmp+1);
    HTML_LOG(0,"return url = [%s]",final);
    FREE(tmp);

    return final;
}

static char *get_drilldown_name(char *root_name,int num_prefix)
{
    char *name = MALLOC(num_prefix + strlen(root_name) + 5 ) ;
    int i;
    for( i = 0 ; i < num_prefix ; i++ ) {
        name[i] = DRILLDOWN_CHAR;
    }
    strcpy(name+i,root_name);
    return name;
}

/**
 * link with all drilldown info removed
 */
char *final_url(char *new_params,char *param_list) 
{

    char *new_drilldown_params = NULL;
    Array *drilldown_root_names=split(param_list,",",0);
    int i;
    if (drilldown_root_names) {
        for(i = 0 ; i < drilldown_root_names-> size ; i++ ) {
            char *param_name = drilldown_root_names->array[i];

            if (param_name) {
                struct hashtable_itr *itr;
                char *qname;
                char *qval;

                for(itr=hashtable_loop_init(g_query) ; hashtable_loop_more(itr,&qname,&qval) ; ) {

                    int depth = is_drilldown_of(qname,param_name);

                    if (depth) {
                        // remove it
                        char *tmp;

                        if (new_drilldown_params == NULL) {
                            ovs_asprintf(&new_drilldown_params,"%s=",qname);
                        } else {
                            ovs_asprintf(&tmp,"%s&%s=",new_drilldown_params,qname);
                            FREE(new_drilldown_params);
                            new_drilldown_params = tmp;
                        }
                    }
                }
            }
        }
    }
    array_free(drilldown_root_names);
TRACE;
    /*
     * Compute the new url
     */
    char *final = self_url2(new_params,new_drilldown_params);
    FREE(new_drilldown_params);

    return final;
}


char *get_self_link(char *params,char *attr,char *title) {

    assert(params);
    assert(attr);
    assert(title);
    char *result=NULL;

    if (strstr(params,"Mark")) {
        HTML_LOG(0," begin self link for params[%s] attr[%s] title[%s]",params,attr,title);
        html_hashtable_dump(0,"query",g_query);
    }

    char *url = self_url(params);
    if (strstr(params,"Mark"))
        HTML_LOG(0," end self link [%s]",url);

    ovs_asprintf(&result,"<a href=\"%s\" %s>%s</a>",url,attr,title);

    FREE(url);
    return result;
}

/*
 * This type of link renames any parameters that are superceeded. eg
 * if p=1 and the drilldown link has p=2 then it becomes..
 * p=2&@p=1
 * this only happens for listed parameters.
 * @params - parameter list 'p=1&q=2'
 * @attr - <a> attributes.
 * @title  <a>title</a>
 */
char *drill_down_link(char *params,char *attr,char *title) {
    assert(params);
    assert(attr);
    assert(title);
    char *result=NULL;

    HTML_LOG(1," begin drill down link for params[%s] attr[%s] title[%s]",params,attr,title);

    char *url = drill_down_url(params,DRILL_DOWN_PARAM_NAMES);
    HTML_LOG(2," end self link [%s]",url);

    ovs_asprintf(&result,"<a href=\"%s\" %s>%s</a>",url,attr,title);

    FREE(url);
    return result;
}

/*
 * This type of link undoes the effect of drill_down_url() ie.
 * p=2&@p=1 becomes p=1
 * this only happens for listed parameters.
 * @params - parameter list 'p=1&q=2'
 * @attr - <a> attributes.
 * @title  <a>title</a>
 * @param_list = list of parameters whose old values are kept in the url.
 */
char *return_link(char *attr,char *title) {
    assert(attr);
    assert(title);
    char *result=NULL;

    HTML_LOG(1," begin drill down link for attr[%s] title[%s]",attr,title);

    char *url = return_url();
    HTML_LOG(2," end drill down link [%s]",url);

    ovs_asprintf(&result,"<a href=\"%s\" %s>%s</a>",url,attr,title);

    FREE(url);
    return result;
}
// This is a link with all drill down parameters removed. This is for the final link
// to play the file.
char *final_link(char *params,char *attr,char *title) {
    assert(params);
    assert(attr);
    assert(title);
    char *result=NULL;

    HTML_LOG(1," begin final link for params[%s] attr[%s] title[%s]",params,attr,title);

    char *url = final_url(params,DRILL_DOWN_PARAM_NAMES);
    HTML_LOG(1," end final link [%s]",url);

    ovs_asprintf(&result,"<a href=\"%s\" %s>%s</a>",url,attr,title);

    FREE(url);
    return result;
}



//void playlist_close() {
//    if (playlist_fp) {
//        fclose(playlist_fp);
//        playlist_fp=NULL;
//    }
//}

FILE *playlist_open() {
    static FILE *fp=NULL;
    static FILE *j=NULL;
    fflush(stdout);
    //HTML_LOG(1,"play list fp is %ld %ld %ld",k,fp,j);
    //exit(1);
    if (fp == NULL) {
        if (unlink(NMT_PLAYLIST) ) {
            HTML_LOG(1,"Failed to delete ["NMT_PLAYLIST"]");
        } else {
            HTML_LOG(1,"deleted ["NMT_PLAYLIST"]");
        }
        j = fp = fopen(NMT_PLAYLIST,"w");
    }
    assert(fp == j); //DONT ASK! ok catch corruption of static area - maybe...
    return fp;
}

char *share_name(DbRowId *r,int *freeme) {
    char *out = NULL;
    *freeme = 0;
    if (*(r->db->source) != '*' ) {
        out = r->db->source;
    } else if (util_starts_with(r->file,NETWORK_SHARE)) {
        char *p = r->file + strlen(NETWORK_SHARE);
        char *q = strchr(p,'/');
        if (q == NULL) {
            out = p;
        } else {
            ovs_asprintf(&out,"%.*s",q-p,p);
            *freeme = 1;
        }
    }
    return out;
}

char *add_network_icon(DbRowId *r,char *text) {

    char *icon;
    char *result=NULL;

    if (*(r->db->source) == '*' && !util_starts_with(r->file,NETWORK_SHARE)) {

        //icon =  get_theme_image_tag("harddisk"," width=20 height=15 ");
        //ovs_asprintf(&result,"%s %s",icon,text);
        //FREE(icon);

    } else {

        icon =  get_theme_image_tag("network"," width=20 height=15 ");
        ovs_asprintf(&result,"%s%s%s",icon,(text?" ":""),NVL(text));
        FREE(icon);

    }

    return result;

}

int has_category(DbRowId *rowid) {
    return (rowid->category == 'T' || rowid->category == 'M' );
}



char *vod_attr(char *file) {

    if (is_dvd(file)) {
        return "file=c ZCD=2";
    } else {
        return "vod file=c";
    }
}

//T2 just to avoid c string handling in calling functions!
char *vod_link(DbRowId *rowid,char *title ,char *t2,
        char *source,char *file,char *href_name,char *href_attr,char *class){

    assert(title);
    assert(t2);
    assert(source);
    assert(file);
    assert(href_name);
    assert(href_attr);
    assert(class);

    char *vod=NULL;
    int freepath;

    int add_to_playlist= has_category(rowid) && !is_dvd(rowid->file);
    char *result=NULL;

    HTML_LOG(1,"VOD file[%s]",file);
    char *path = get_path(rowid,file,&freepath);
    HTML_LOG(1,"VOD path[%s]",path);

    nmt_mount(path);

    char *encoded_path = url_encode(path);


    if (!g_dimension->local_browser && browsing_from_lan()) {

        if (*oversight_val("ovs_tv_play_via_pc") == '1') {
            //If using a browser then VOD tags dont work. Make this script load the file into gaya
            //Note we send the view and idlist parameters so that we can render the original page 
            //in the brower after the infomation is sent to gaya.

            //This works by adding a parameter REMOTE_VOD_PREFIX1=filename
            //The script than captures this after clicking via do_actions,
            //this sends a url to gaya which points back to this script again but will just contain
            //small text to auto load a file using <a onfocusload> and <body onloadset>
            char *params =NULL;
            ovs_asprintf(&params,REMOTE_VOD_PREFIX1"=%s",encoded_path);
            //ovs_asprintf(&params,"idlist=&"QUERY_PARAM_VIEW"=&"REMOTE_VOD_PREFIX1"=%s",encoded_path);
            //
            result = get_final_link_with_font(params,class,title,class);
            //result = get_self_link_with_font(params,class,title,class); XX
            FREE(params);

        } else {
            ovs_asprintf(&result,"<font class=\"%s\">%s</font>",class,title);
        }

    } else {

        ovs_asprintf(&vod," %s name=\"%s?1\" %s ",vod_attr(file),href_name,href_attr);

        if (add_to_playlist) {
            //Build playlist array for this entry.
            if (rowid->playlist_names == NULL) rowid->playlist_names = array_new(free);
            if (rowid->playlist_paths == NULL) rowid->playlist_paths = array_new(free);
            array_add(rowid->playlist_names,util_basename(file));
            array_add(rowid->playlist_paths,STRDUP(path));
        }


        if (!EMPTY_STR(class)) {

            ovs_asprintf(&result,"<a href=\"file://%s\" %s %s><font %s>%s%s</font></a>",
                    encoded_path,vod,class,class,title,t2);
        } else {
            ovs_asprintf(&result,"<a href=\"file://%s\" %s>%s%s</a>",
                    encoded_path,vod,title,t2);
        }
    }

    FREE(encoded_path);
    if (freepath) FREE(path);
    FREE(vod);

    return result;
}

// this is a link where existing p,view,idlist parameters are moved to @p,@view,@idlist 
// so  after following this link we have enough info to generate a link to return
char *get_drilldown_link_with_font(char *params,char *attr,char *title,char *font_attr)
{
    assert(params);
    assert(attr);
    assert(title);
    assert(font_attr);
    char *title2=NULL;

    ovs_asprintf(&title2,"<font %s>%s</font>",font_attr,title);
    char *result = drill_down_link(params,attr,title2);

    FREE(title2);
    return result;
}

// This is a link with all drill down parameters removed. This is for the final link
// to play the file.
char *get_final_link_with_font(char *params,char *attr,char *title,char *font_attr)
{
    assert(params);
    assert(attr);
    assert(title);
    assert(font_attr);
    char *title2=NULL;

    ovs_asprintf(&title2,"<font %s>%s</font>",font_attr,title);
    char *result = final_link(params,attr,title2);

    FREE(title2);
    return result;
}

char *get_self_link_with_font(char *params,char *attr,char *title,char *font_attr)
{
    assert(params);
    assert(attr);
    assert(title);
    assert(font_attr);
    char *title2=NULL;

    ovs_asprintf(&title2,"<font %s>%s</font>",font_attr,title);
    char *result = get_self_link(params,attr,title2);

    FREE(title2);
    return result;
}


void display_self_link(char *params,char *attr,char *title)
{
    char *tmp;
    tmp=get_self_link(params,attr,title);
    printf("%s",tmp);
    FREE(tmp);
}


char *get_remote_button(char *button_colour,char *params,char *text)
{

    assert(button_colour);
    assert(params);
    assert(text);

    char *params2;
    char *attr;
    char *text2;

    ovs_asprintf(&params2,"%s&colour=%s",params,button_colour);
    ovs_asprintf(&attr,"tvid=\"%s\"",button_colour);
    ovs_asprintf(&text2,"<font class=\"%sbutton\">%s</font>",button_colour,text);

    char *result = get_self_link(params2,attr,text2);

    FREE(params2);
    FREE(attr);
    FREE(text2);
    return result;
}


char *get_toggle(char *button_colour,char *param_name,char *v1,char *text1,char *v2,char *text2)
{

    assert(button_colour);
    assert(param_name);
    assert(v1);
    assert(text1);
    assert(v2);
    assert(text2);

    char *param_value;
    char *params;
    char *text;
    char *next = v1;
    int v1current = 0;
    int v2current = 0;

    param_value = query_val(param_name);

    if (!*param_value) {

        //next = v1;
        //v1current = v2current = 0;
        v2current = 1;
        next = v1;

    } else if (strcmp(param_value,v1)==0) {

        v1current = 1;
        next = v2;

    } else if (strcmp(param_value,v2)==0) {
            
        v2current = 1;
        next = v1;
        //next = "";
    }

    ovs_asprintf(&params,"p=0&%s=%s",param_name,next);

    HTML_LOG(1,"params = [%s]",params);

    ovs_asprintf(&text,"%s%s%s<br>%s%s%s",
            (v1current?"<u><b>":""),text1,(v1current?"</b></u>":""),
            (v2current?"<u><b>":""),text2,(v2current?"</b></u>":""));

    HTML_LOG(1,"toggle text = [%s]",text);

    char *result = get_remote_button(button_colour,params,text);

    FREE(params);
    FREE(text);
    return result;
}

//Add current named html parameter as a hidden value
char * add_hidden(char *name_list) {
    char *output="";
    Array *names = split(name_list,",",0);
    int i;
    for(i = 0 ; i < names->size ; i++ ) {

        char *name =names->array[i];
        char *val = query_val(name);

        if (*val) {

            char *tmp;
            ovs_asprintf(&tmp,"%s<input type=hidden name=\"%s\" value=\"%s\" >\n",output,name,val);
            if (*output) FREE(output);
            output = tmp;
        }
    }
    if (!*output) {
        return NULL;
    } else {
        return output;
    }
}

void display_submit(char *name,char *value) {
    assert(name);
    assert(value);
    printf("<input type=submit name=\"%s\" value=\"%s\">",name,value);
}

void display_confirm(char *name,char *val_ok,char *val_cancel) {
    printf("<table width=100%%><tr><td align=center>");
    display_submit(name,val_ok);
    printf("</td><td align=center>");
    display_submit(name,val_cancel);
    printf("</td></tr></table>");
}


void display_footer(
        ) {
    printf("Footer here");
}

/*
 * html code for an image link where url will drillup - ie remap @@param to @param
 * and @param to param.
 */
char *get_theme_image_return_link(char *href_attr,char *image_name,char *button_attr)
{
    assert(image_name);

    char  *tag=get_theme_image_tag(image_name,button_attr);
    char *result = return_link(href_attr,tag);
    FREE(tag);
    return result;
}
char *get_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr)
{
    assert(qlist);
    assert(image_name);

    char  *tag=get_theme_image_tag(image_name,button_attr);
    char *result = get_self_link(qlist,href_attr,tag);
    FREE(tag);
    return result;
}
void display_theme_image_link(char *qlist,char *href_attr,char *image_name,char *button_attr)
{

    assert(qlist);
    assert(image_name);

    char  *tag=get_theme_image_tag(image_name,button_attr);
    display_self_link(qlist,href_attr,tag);
    FREE(tag);
}

char *add_scroll_attributes(int left_scroll,int right_scroll,int selected_cell,char *attrin)
{
    char *attr;
    ovs_asprintf(&attr,
            " %s%s%s %s ",
            (selected_cell? "name=selectedCell ":""),
            (left_scroll? "onkeyleftset=pgup1 ":""),
            (right_scroll? "onkeyrightset=pgdn1 ":""),

            (attrin != NULL?attrin:""));

    return attr;
}

char *get_empty(char *width_attr,int grid_toggle,char *height_attr,int left_scroll,int right_scroll,int selected_cell) {

    char *attr;

    attr=add_scroll_attributes(left_scroll,right_scroll,selected_cell,NULL);

    char *result;

    ovs_asprintf(&result,"\t\t<td %s %s class=empty%d><a href=\"\" %s></a>\n",
            width_attr,height_attr,grid_toggle,attr);

    FREE(attr);
    return result;
}


static int use_file_to_url_symlink=0;
void create_file_to_url_symlink() {
    // Create a symlink that gives a remote browse simple access to all
    // files via http://ip:8883/...
    // By default remote browsers can only see /opt/httpd/default and
    // only gaya can see the other media mount points eg /opt/sybhttpd/localhost.drives
    // (becuase sybhttpd checks the headers sent back by the browser (see mini-installer)
    // This link allows /NETWORK_SHARE/path/to/file to be accessed as
    // http://:8883/.network/path/to/file
    //
    // This is a potential security risk so well make it optional
    // Without it - remote browsers  access mounted images by passing them as an argument
    // to oversight.cgi which then 'cats' them to stdout - see main()
    if (!exists(NETWORK_SYMLINK)) {
        symlink(NETWORK_SHARE,NETWORK_SYMLINK);
    }
    use_file_to_url_symlink=1;
}

char *file_to_url(char *path) {
    char *new = NULL;
    assert(path);
    if (g_dimension->local_browser) {
        //If using gaya just go directly to the file system
        ovs_asprintf(&new,"\"file://%s\"",path);

    } else if (util_starts_with(path,"/share/Apps/oversight")) {
        // if /share/Apps/oversight/file/path 
        // then use /oversight/file/path thanks to symlink 
        //  /opt/sybhttpd/default/oversight -> /share/Apps/oversight/
        ovs_asprintf(&new,"\"%s\"",path+11);

    } else if (util_starts_with(path,"/opt/sybhttpd/default")) {
        // if in /opt/sybhttpd/default/file/path
        // then use /file/path
        ovs_asprintf(&new,"\"%s\"",path+21);

    } else if (use_file_to_url_symlink && util_starts_with(path,NETWORK_SHARE)) {
        ovs_asprintf(&new,"\"/.network/%s\"",path+strlen(NETWORK_SHARE));
    } else {
        // otherwise pass as a paramter to this script. It will cat jpg etc it to stdout
        ovs_asprintf(&new,"\"?%s\"",path);
    }
    return new;

}

char * get_local_image_link(char *path,char *alt_text,char *attr) {

    assert(path);
    assert(alt_text);
    assert(attr);

    char *result;


    if (!exists(path) ) {
        result = STRDUP(alt_text);
        HTML_LOG(0,"%s doesnt exist",path);
    } else {
        char *img_src = file_to_url(path);
        ovs_asprintf(&result,"<img alt=\"%s\" src=%s %s >",alt_text,img_src,attr);
        FREE(img_src);
    }
    return result;
}


char *category(char cat) {
    switch(cat) {
        case 'T' : return "tv";
        case 'M' : return "movie";
        default : return "video";
    }
}

char *file_style_custom(DbRowId *rowid,char *modifier) {

    static char grid_class[50],c='\0';

    if (g_dimension->poster_mode) {
        return " class=unwatched ";
    } else {

        /* Plan to depricate this one day */
        sprintf(grid_class," class=grid_%s%s%s ",
                category(rowid->category),
                (rowid->watched?"_watched":""),
                modifier);
        assert(c == 0);
    }

    return grid_class;
}
char *file_style(DbRowId *rowid) {
    return file_style_custom(rowid,"");
}
char *file_style_small(DbRowId *rowid) {
    return file_style_custom(rowid,"_small");
}

// Item is marked watched if all linked rows are watched.
int is_watched(DbRowId *rowid) {
    int result=1;
    for( ; rowid ; rowid = rowid->linked ) {
        if (rowid->watched == 0) {
            result=0;
            break;
        }
    }
    return result;
}


int is_fresh(DbRowId *rowid) {
    int result=0;
    static long fresh_time = -1;

    if (fresh_time == -1 ) {

        long fresh_days;
        fresh_time = 0;
        if (config_check_long(g_oversight_config,"ovs_new_days",&fresh_days)) {
            fresh_time = time(NULL) -fresh_days*24*60*60 ;
        } else {
            fresh_time = 0;
        }
    }

    // Item is marked fresh if any row is fresh
    if (fresh_time > 0) {
        for( ; rowid ; rowid = rowid -> linked ) {
            if (internal_time2epoc(rowid->date) > fresh_time) {
                result=1;
                break;
            }
        }
    }
    return result;
}

char *watched_style(DbRowId *rowid) {

    if (is_watched(rowid)) {
        return " class=watched ";
    } else if (is_fresh(rowid) ) {
        return " class=fresh ";
    } else { 
        return file_style(rowid);
    }
}
char *watched_style_small(DbRowId *rowid) {

    if (is_watched(rowid)) {
        return " class=watched_small ";
    } else if (is_fresh(rowid) ) {
        return " class=fresh_small ";
    } else { 
        return file_style_small(rowid);
    }
}

char *check_path(char *format, ... ) {
    char *p;
    va_list args;
    va_start(args,format);
    ovs_vasprintf(&p,format,args);

    va_end(args);

    if (!exists(p)) {
        HTML_LOG(1,"%s doesnt exist",p);
        FREE(p);
        p = NULL;
    } else {
        HTML_LOG(1,"%s exist",p);
    }
    return p;
}

char *internal_image_path_static(DbRowId *rid,ImageType image_type)
{
    // No pictures on filesystem - look in db
    // first build the name 
    // TV shows = ovs:fieldid/prefix title _ year _ season.jpg
    // films  = ovs:fieldid/prefix title _ year _  imdbid.jpg
    //
#define INTERNAL_IMAGE_PATH_LEN 250
    static char path[INTERNAL_IMAGE_PATH_LEN+1];
    path[INTERNAL_IMAGE_PATH_LEN] = '\0';
    char *p = path;
    p += sprintf(p,"ovs:%s/%s",
            (image_type == FANART_IMAGE?DB_FLDID_FANART:DB_FLDID_POSTER),
            catalog_val("catalog_poster_prefix"));
    char *t=rid->title;

    // Add title replacing all runs of non-alnum with single _
    int first_nonalnum = 1;
    while(*t) {
        if (isalnum(*t) || strchr("-_",*t) ) {
            *p++ = *t;
            first_nonalnum=1;
        } else if (first_nonalnum) {
            *p++ = '_';
            first_nonalnum=0;
        } else {
            p++;
        }
        t++;
    }
    if (rid->category == 'T' ) {
        p+= sprintf(p,"_%d_%d.jpg",rid->year,rid->season);
    } else {
        char *imdbid=NULL;
TRACE;
        if (!EMPTY_STR(rid->url ) ) {
           if ( util_starts_with(rid->url,"tt")) {
               imdbid = rid->url;
           } else {
               imdbid = strstr(rid->url,"/tt");
               if (imdbid && isdigit(imdbid[3])) imdbid ++;
           }
        }
TRACE;
        HTML_LOG(1,"imdbid=[%s]",imdbid);
        if (imdbid) {
           p += sprintf(p,"_%d_%.9s.jpg",rid->year,imdbid);
            HTML_LOG(1,"path=[%s]",path);
        } else {
            // Blank it all out
            *path = '\0';
            HTML_LOG(2,"internal_image_path_static [%s] = NULL",rid->title);
            return NULL;
        }
    }
    HTML_LOG(2,"internal_image_path_static [%s] = [%s]",rid->title,path);
    assert(path[INTERNAL_IMAGE_PATH_LEN] == '\0');
    return path;
}

char *get_internal_image_path_any_season(int num_rows,DbRowId **sorted_rows,ImageType image_type);
char *get_existing_internal_image_path(DbRowId *rid,ImageType image_type);

char *get_picture_path(int num_rows,DbRowId **sorted_rows,ImageType image_type) {

    char *path = NULL;
    DbRowId *rid = sorted_rows[0];
    char *modifier="";

    if (image_type == FANART_IMAGE) {
        modifier="fanart.";
    }

    int freefile;
    // First check the filesystem. We do this via the mounted path.
    // This requires that the remote file is already mounted.
    char *file = get_path(rid,rid->file,&freefile);
TRACE;
    char *dir = util_dirname(file);

    // Find position of file extension.
    char *dot = NULL;

    // First look for file.modifier.jpg file.modifier.png
    if (rid->ext != NULL) { 
        dot = strrchr(file,'.');
        if (dot) {
            dot++;
        }
    }

    // note this could be re-written with util_change_extension()
    path=check_path("%.*s%sjpg",dot-file,file,modifier);

    if (path == NULL) path=check_path("%.*s%spng",dot-file,file,modifier);

    if (path == NULL) path=check_path("%s/%sjpg",dir,(image_type == FANART_IMAGE?modifier:"poster."));
    if (path == NULL) path=check_path("%s/%spng",dir,(image_type == FANART_IMAGE?modifier:"poster."));

    if (freefile) FREE(file);
    FREE(dir);

    if (path == NULL) {

        // look in internal db
        path = get_internal_image_path_any_season(num_rows,sorted_rows,image_type);
    }

    return path;
}

/**
 * If looking at the box set view try each season in turn
 */
char *get_internal_image_path_any_season(int num_rows,DbRowId **sorted_rows,ImageType image_type)
{

    int i;
    int season=-2;
    char * path = NULL;
    for ( i= 0 ; path == NULL && i < num_rows ; i++ ) {
        if (season == -2 || sorted_rows[i]->season != season) {
            season = sorted_rows[i]->season;
            path = get_existing_internal_image_path(sorted_rows[i],image_type);
        }
    }
    return path;
}

/*
 * Get the full internal image path if it exists.
 */
char *get_existing_internal_image_path(DbRowId *rid,ImageType image_type)
{
    char *path = internal_image_path_static(rid,image_type);

    if (path) {
        int freepath=0;
        path = get_path(rid,path,&freepath);
TRACE;

        if (image_type == FANART_IMAGE ) {
TRACE;
            char *modifier=".hd.jpg";

            if (g_dimension->scanlines == 0 ) {

                if (g_dimension->is_pal ) {
                    modifier=".pal.jpg";
                } else {
                    modifier=".sd.jpg";
                }
            }
            char *tmp = util_change_extension(path,modifier);
            if(freepath) FREE(path);
            path = tmp;

        } else if (image_type == THUMB_IMAGE ) {

            char *tmp = util_change_extension(path,".thumb.jpg");
            if (exists(tmp)) {
                if(freepath) FREE(path);
                path = tmp;
            } else {
                FREE(tmp);
                if(!freepath && path) {
                    path=STRDUP(path);
                }
            }
        }
        if(!exists(path) ) {
            HTML_LOG(0,"[%s] doesnt exist",path);
            FREE(path);
            path=NULL;
        }
    }
    return path;
}


char * get_poster_image_tag(DbRowId *rowid,char *attr,ImageType image_type) {

    assert(rowid);
    assert(attr);
TRACE;
    char *result = NULL;
    
    char *path = get_picture_path(1,&rowid,image_type);
TRACE;
    if (path) {
TRACE;

        result = get_local_image_link(path,rowid->title,attr);
TRACE;

        FREE(path);
    }
TRACE;
    return result;
}

char *ovs_icon_type() {
    static char *icon_type = NULL;
    static char *i=NULL;
    if (icon_type == NULL) {
        if (!config_check_str(g_oversight_config,"ovs_icon_type",&icon_type)) {
            icon_type="png";
        }
        HTML_LOG(1,"icon type = %s",icon_type);
        i = icon_type;
    }
    assert(icon_type == i );
    return icon_type;
}

char *container_icon(char *image_name,char *name) {
    char *path;
    char *name_br;

    ovs_asprintf(&path,"%s/templates/%s/images/%s.%s",appDir(),skin_name(),image_name,ovs_icon_type());
    ovs_asprintf(&name_br,"(%s)",name);

    char *result = get_local_image_link(path,name_br,"class=\"codec\"");

    FREE(path);
    FREE(name_br);
    return result;
}

//free result
char *icon_link(char *name) {

    char *result=NULL;

    if (name) {
        if (name[strlen(name)-1] == '/') {
            result = container_icon("video_ts","vob");
        } else {
            //char *ext = name + strlen(name) - 5;
            char *ext = strrchr(name,'.');
            if (ext != NULL) {
                ext++;
                char *p;
                if ((p = strstr("|iso|img|mkv|avi|",ext)) != NULL && p[-1] == '|' && p[strlen(ext)] == '|' ) {
                    result = container_icon(ext,ext);
                } else if (strcasecmp(ext,"avi") != 0) {
                    ovs_asprintf(&result,"<font size=\"-1\">[%s]</font>",ext);
                }
            }
        }
    }
    return result;
}



char *build_ext_list(DbRowId *row_id) {

    HTML_LOG(3,"ext=%s",row_id->ext);
    char *ext_icons = icon_link(row_id->ext);
    HTML_LOG(3,"ext_icons=%s",ext_icons);

    DbRowId *ri;
    for( ri = row_id->linked ; ri ; ri=ri->linked ) {
        if (ri->ext && (ext_icons==NULL || strstr(ext_icons,ri->ext) == NULL)) {
            char *new_ext;
            char *linked_icon = icon_link(ri->ext);
            if (linked_icon) {
                ovs_asprintf(&new_ext,"%s%s",
                        (ext_icons?ext_icons:""),
                        (linked_icon?linked_icon:""));
                FREE(linked_icon);
                FREE(ext_icons);
                ext_icons = new_ext;
            }
        }
    }
    return ext_icons;
}

char *add_one_source_to_idlist(DbRowId *row_id,char *current_idlist,int *mixed_sources) {

    char *idlist=NULL;
    assert(row_id);
    assert(row_id->db);
    assert(row_id->db->source);
    ovs_asprintf(&idlist,"%s%s(%ld|",
            NVL(current_idlist),
            row_id->db->source,row_id->id);
    FREE(current_idlist);

    if (mixed_sources) *mixed_sources=0;

    DbRowId *ri;
    for( ri = row_id->linked ; ri ; ri=ri->linked ) {
        if (strcmp(ri->db->source,row_id->db->source) == 0) {
            char *tmp;
            // Add all other items with the same source
            ovs_asprintf(&tmp,"%s%ld|",idlist,ri->id);
            FREE(idlist);
            idlist = tmp;
        } else {
            if (mixed_sources) *mixed_sources=1;
        }
    }
    idlist[strlen(idlist)-1] = ')';
    return idlist;
}

/*
 * Go through all Ids that are linked and create an id list of the form.
 * source(id1|id2|id3)source2(id4|id5|id6)
 * In the menu view all rows with the same season are linked.
 * in the tv view , rows with the same file are linked.
 */
char *build_id_list(DbRowId *row_id) {

    int mixed_sources=0;
    char *idlist=NULL;
    assert(row_id);
    assert(row_id->db);
    assert(row_id->db->source);

    idlist = add_one_source_to_idlist(row_id,NULL,&mixed_sources);

    idlist[strlen(idlist)-1] = ')';

    if (mixed_sources) {
        // Add rows from other sources. This could be merged with the loop above
        // but to help performance we only track sources if we need to as the loop
        // performance is O(n^2)
        struct hashtable *sources = string_string_hashtable(4);
        hashtable_insert(sources,row_id->db->source,"1");
        DbRowId *ri;

        for( ri = row_id->linked ; ri ; ri=ri->linked ) {
            if (hashtable_search(sources,ri->db->source) == NULL) {
                hashtable_insert(sources,ri->db->source,"1");
                idlist = add_one_source_to_idlist(ri,idlist,&mixed_sources);
            }
        }
        hashtable_destroy(sources,0,0);
    }

    return idlist;
}

#define MAX_TITLE_LEN 50
char *trim_title(char *title) {
    char *out = STRDUP(title);
    if (strlen(out) > MAX_TITLE_LEN) {
        strcpy(out+MAX_TITLE_LEN-3,"..");
    }
    return out;
}


char *select_checkbox(DbRowId *rid,char *text) {
    char *result = NULL;
    char *select = query_val("select");

    if (*select) {

        char *id_list = build_id_list(rid);

        if (rid->watched && strcmp(select,"Mark") == 0) {

            ovs_asprintf(&result,
                "<input type=checkbox name=\""CHECKBOX_PREFIX"%s\" CHECKED >"
                "<input type=hidden name=\"orig_"CHECKBOX_PREFIX"%s\" value=on>"
                "<font class=%s>%s</font>",
                    id_list,
                    id_list,
                    select,text);
        } else {

            ovs_asprintf(&result,
                "<input type=checkbox name=\""CHECKBOX_PREFIX"%s\" >"
                "<font class=%s>%s</font>",
                    id_list,
                    select,text);
        }
        FREE(id_list);
    } else {
        ovs_asprintf(&result,"<font class=Ignore>%s</font>",text);
    }
    return result;
}



char *movie_listing(DbRowId *rowid) {

    db_rowid_dump(rowid);

    char *tmp = build_id_list(rowid);
    printf("<script type=\"text/javascript\"><!--\ng_title='%s';\ng_idlist='%s';\n--></script>\n",
            rowid->title,tmp);
    FREE(tmp);


    char *select = query_val("select");
    char *style = watched_style(rowid);
    if (*select) {
        return select_checkbox(rowid,rowid->file);
    } else {
        char *result=NULL;
        Array *parts = split(rowid->parts,"/",0);
        HTML_LOG(1,"parts ptr = %ld",parts);

        char *basename=util_basename(rowid->file);

        result=vod_link(rowid,basename,"",rowid->db->source,rowid->file,"0","onkeyleftset=up",style);
        FREE(basename);
        // Add vod links for all of the parts
        
        if (parts && parts->size) {

            int i;
            for(i = 0 ; i < parts->size ; i++ ) {

                char i_str[10];
                sprintf(i_str,"%d",i);

                char *tmp=vod_link(rowid,parts->array[i],"",rowid->db->source,parts->array[i],i_str,"",style);

                char *vod_list;
                ovs_asprintf(&vod_list,"%s<br>\n%s",result,tmp);
                FREE(tmp);
                FREE(result);
                result=vod_list;
            }
        }

        // Big play button
        char *play_button = get_theme_image_tag("player_play","");
        char *play_tvid;
        if (is_dvd(rowid->file)) {
            // DVDs are not added to the play list. So the play button just plays the dvd directly
            play_tvid = vod_link(rowid,play_button,"",rowid->db->source,rowid->file,"1","",style);
        } else {
            play_tvid = get_play_tvid(play_button);
        }

        char *vod_list;
        ovs_asprintf(&vod_list,"<table><tr><td>%s</td><td>%s</td></table>",play_tvid,result);
        FREE(result);
        result = vod_list;
        FREE(play_button);
        FREE(play_tvid);
        return result;
    }
}


// Count number of unique seasons in the list.
int season_count(DbRowId *rid) {
#define WORDS 8
#define WORDBITS 16

    // First push seasons into a set (bits)
    int i=0;
    int j=0;
    unsigned long bitmask[WORDS];
    memset(bitmask,0,WORDS * sizeof(long));

    //HTML_LOG(0,"Season count [%s]",rid->title);
    for(  ; rid ; rid=rid->linked) {
        if (rid->category == 'T') {
            i=rid->season / WORDBITS;
            j=rid->season % WORDBITS;
            bitmask[i] |= (1 << j ); // allow for season 0 - prequels - pilots.
            //HTML_LOG(0,"%d -> [%d][%d]=%lx",rid->season,i,j,bitmask[i]);
        }
    }


    // Now count total bits set.
    int total=0;
    for(i=0 ; i < WORDS ; i++ ) {
        for(j=1 ; j ; j = j << 1 ) {
           if (bitmask[i] & j ) total++;
        }
        //HTML_LOG(0,"total at word %d -> %d",i,total);
    }

    return total;
}

int group_count(DbRowId *rid) {
    int i=0;
    for(  ; rid ; rid=rid->linked) {
        i++;
    }
    return i;
}

void get_watched_counts(DbRowId *rid,int *watchedp,int *unwatchedp) 
{
    int watched=0;
    int unwatched=0;
    for(  ; rid ; rid=rid->linked) {
        if (rid->watched ) {
            watched++;
        } else {
            unwatched++;
        }
    }
    if (watchedp) *watchedp = watched;
    if (unwatchedp) *unwatchedp = unwatched;
}
    
int unwatched_count(DbRowId *rid) {
    int i=0;
    get_watched_counts(rid,NULL,&i);
    return i;
}

int watched_count(DbRowId *rid) {
    int i=0;
    get_watched_counts(rid,&i,NULL);
    return i;
}

typedef enum { WATCHED , NORMAL , FRESH } ViewStatus;

int get_view_status(DbRowId *rowid) {
    ViewStatus status = NORMAL;
    if (is_watched(rowid)) {
        status = WATCHED;
    } else if (is_fresh(rowid)) {
        status = FRESH;
    }
    return status;
}

char *get_poster_mode_item(DbRowId *row_id,char **font_class,char **grid_class) {

    char *title = NULL;
    HTML_LOG(2,"dbg: tv or movie : set details as jpg");
TRACE;
    ViewStatus status = get_view_status(row_id);



    // *font_class and *grid_class are returned to the caller to set the <a><font> class and the <td>
    switch(status) {
        case NORMAL:  *grid_class = "class=poster"; break;
        case FRESH:   *grid_class = "class=poster_fresh"; break;
        case WATCHED: *grid_class = "class=poster_watched"; break;
        default:
             assert(0);
    }
    *font_class = *grid_class;


#if 0
    char *attr;
    // The class is reused here to set the image tag
    // They just happen to have the same name - maybe there is a more css friendly way to do this!
    ovs_asprintf(&attr," width=%d height=%d %s ",
        g_dimension->poster_menu_img_width,
        g_dimension->poster_menu_img_height,
        *font_class);

    title = get_poster_image_tag(row_id,attr,THUMB_IMAGE);
    FREE(attr);
#else
    title = get_poster_image_tag(row_id,*font_class,THUMB_IMAGE);
#endif
TRACE;

TRACE;
    return title;
}

char *get_poster_mode_item_unknown(DbRowId *row_id,char **font_class,char **grid_class) {
    HTML_LOG(2,"dbg: unclassified : set details as title");
    // Unclassified
    char *title=STRDUP(row_id->title);
    if (strlen(title) > 20) {
        strcpy(title+18,"..");
    }
    if (is_watched(row_id)) {
        *grid_class = "class=poster_watched_unknown";
    } else if (is_fresh(row_id)) {
        *grid_class = "class=poster_fresh_unknown";
    } else {
        *grid_class = "class=poster_unknown";
    }
    *font_class = watched_style_small(row_id);
    return title;
}

char *get_text_mode_item(DbRowId *row_id,char **font_class,char **grid_class,char *newview) {
    int tv_or_movie = has_category(row_id);
    // TEXT MODE
    HTML_LOG(2,"dbg: get text mode details ");

    *font_class = watched_style(row_id);
    *grid_class = file_style(row_id);

    char *title = trim_title(row_id->title);
   
    char *tmp;
    if (strcmp(newview,VIEW_TVBOXSET) == 0) {

        ovs_asprintf(&tmp,"%s [%d Seasons]",title,season_count(row_id));
        FREE(title);
        title = tmp;

    } else {

       char *cert = row_id->certificate;
       if ((tmp=strchr(cert,':')) != NULL) {
           if (tmp[1] != '\0') {
               ovs_asprintf(&cert,"(%s)",tmp+1);
           } else {
               cert = NULL;
           }
       }

        if (row_id->category == 'T' && row_id->season >= 1) {
            //Add season
            char *tmp;
            ovs_asprintf(&tmp,"%s S%d",title,row_id->season);
            FREE(title);
            title=tmp;
        }

        if (tv_or_movie) {
            HTML_LOG(2,"dbg: add certificate");
            //Add certificate and extension
            char *tmp;
            char *ext_icons=build_ext_list(row_id);
            HTML_LOG(2,"dbg: add extension [%s]",ext_icons);

            ovs_asprintf(&tmp,"%s %s %s",
                    title,
                    (cert?cert:""),
                    (ext_icons?ext_icons:""));

            FREE(title);
            title=tmp;
            if (cert != row_id->certificate) FREE(cert);
            FREE(ext_icons);
        }


        if (row_id->category == 'T') {
            HTML_LOG(2,"dbg: add episode count");
            //Add episode count

            int unwatched = unwatched_count(row_id);

            if (unwatched) {
                char *tmp;
                int total = group_count(row_id);
                ovs_asprintf(&tmp,"%s&nbsp;<font color=#AAFFFF size=-1>x%d of %d</font>",title,unwatched,total);
                FREE(title);
                title=tmp;
            }
        }

        long crossview=0;
        config_check_long(g_oversight_config,"ovs_crossview",&crossview);
        if (crossview == 1 && *(row_id->db->source) != '*') {
            HTML_LOG(2,"dbg: add network icon");
           char *tmp =add_network_icon(row_id,title);
           FREE(title);
           title = tmp;
        }
    }
    HTML_LOG(0,"title[%s] newview[%s] final title[%s]",row_id->title,newview,title);

    return title;
}


char *get_simple_title(
        DbRowId *row_id,
        char *newview   // VIEW_TV , VIEW_MOVIE , VIEW_TVBOXSET , VIEW_MOVIEBOXSET , VIEW_MIXED
        ) {
    char *title;
    char *source=row_id->db->source;
    int show_source = (source && *source != '*');

    if (newview == NULL ) {
        newview = get_drilldown_view(row_id);
    }

    char *source_start,*source_end;
    source_start = source_end = "";
    if (show_source) {
        source_start=" [";
        source_end="]";
    }

    if (strcmp(newview,VIEW_TVBOXSET) == 0) {

        ovs_asprintf(&title,"%s [%d Seasons]",row_id->title,season_count(row_id));

    } else if (row_id->category=='T') {

        ovs_asprintf(&title,"%s S%d %s%s%s",row_id->title,row_id->season,
            source_start,(show_source?source:""),source_end);

    } else if (row_id->year) {

        ovs_asprintf(&title,"%s (%d) %s %s%s%s",row_id->title,row_id->year,
                NVL(row_id->certificate),
                source_start,(show_source?source:""),source_end);

    } else {

        ovs_asprintf(&title,"%s %s %s%s%s",row_id->title,
                NVL(row_id->certificate),
                source_start,(show_source?source:""),source_end);
    }
    return title;
}
char *mouse_or_focus_event_fn(char *function_name_prefix,long function_id,char *on_event,char *off_event) {
    char *result = NULL;
    if (off_event != NULL) {
        ovs_asprintf(&result," %s=\"%s%lx();\" %s=\"%s0();\"",
                on_event,function_name_prefix,function_id,
                off_event,function_name_prefix);
    } else {
        ovs_asprintf(&result," %s=\"%s%lx();\"",
                on_event,function_name_prefix,function_id);
    }
    return result;
}

// These are attributes of the href
char *focus_event_fn(char *function_name_prefix,long function_id,int out_action) {
    return mouse_or_focus_event_fn(function_name_prefix,function_id,"onfocus",
            (out_action?"onblur":NULL));
}

// These are attributes of the cell text
char *mouse_event_fn(char *function_name_prefix,long function_id,int out_action) {
    return mouse_or_focus_event_fn(function_name_prefix,function_id,"onmouseover",
            (out_action?"onmouseout":NULL));
}

char *get_item(int cell_no,DbRowId *row_id,int grid_toggle,char *width_attr,char *height_attr,
        int left_scroll,int right_scroll,int selected_cell,char *idlist)
{

    //TODO:Highlight matched bit
    HTML_LOG(2,"Item %d = %s %s %s",cell_no,row_id->db->source,row_id->title,row_id->file);

    char cell_no_txt[9];
    sprintf(cell_no_txt,"%d",cell_no);

    char *title=NULL;
    char *font_class="";
    char *grid_class="";

    char *select = query_val("select");
    int tv_or_movie = has_category(row_id);
    char *cell_background_image=NULL;
    int displaying_text;

    //Gaya has a navigation bug in which highlighting sometimes misbehaves on links 
    //with multi-lines of text. This was not a problem until the javascript title display
    //was introduced. When the bug triggers all elements become unfocussed causing
    //navigation position to be lost. 
    //To circumvent bug - only the first word of the link is highlighted.
    char *first_space=NULL;
    int link_first_word_only = g_dimension->local_browser && g_dimension->title_bar;

    char *newview = get_drilldown_view(row_id);

    if (in_poster_mode() ) {
        displaying_text=0;
        if (tv_or_movie && (title = get_poster_mode_item(row_id,&font_class,&grid_class)) != NULL) {

            if (*title != '<' && !util_starts_with(title,"<img")) {
                displaying_text=1;
                first_space = strchr(title,' ');
            }

        } else {
            title = get_poster_mode_item_unknown(row_id,&font_class,&grid_class);
            displaying_text=1;
        }
TRACE;
        if (displaying_text) {
TRACE;

            if (link_first_word_only) {
                //
                //Reduce amount of text in link - to fix gaya navigation
                first_space = strchr(title,' ');
            }

TRACE;
            // Display alternate image - this has to be a cell background image
            // so ewe can overlay text on it. as NTM does not have relative positioning
            // the alternative is to render the page and then use javascript to inspect
            // the cell coordinates and then overlay the text. yuk
            switch (row_id->category) {
                case 'T':
                    cell_background_image=icon_source("tv"); break;
                case 'M':
                case 'F':
                    cell_background_image=icon_source("video"); break;
                default:
                    cell_background_image=icon_source("video"); break;
            }
TRACE;
        }

    } else {
        displaying_text=1;

        title = get_text_mode_item(row_id,&font_class,&grid_class,newview);
    }
    if (first_space) {
        // Truncate even more if the first space does not occur early enough in the title.
        if (first_space - title > 11 ) {
            first_space = title+11;
        }
        *first_space='\0';
    }
TRACE;
    char *cell_text=NULL;
    char *focus_ev = "";
    char *mouse_ev = "";

    if (g_dimension->title_bar && !*select) {

        char *simple_title = get_simple_title(row_id,newview);

        focus_ev = focus_event_fn(JAVASCRIPT_MENU_FUNCTION_PREFIX,cell_no+1,1);
        if (!g_dimension->local_browser) {
            mouse_ev = mouse_event_fn(JAVASCRIPT_MENU_FUNCTION_PREFIX,cell_no+1,1);
        }
        FREE(simple_title);
    }
TRACE;

    char *title_change_attr;
    ovs_asprintf(&title_change_attr," %s %s" ,(grid_class?grid_class:""), focus_ev);


    char *attr = add_scroll_attributes(left_scroll,right_scroll,selected_cell,title_change_attr);
    FREE(title_change_attr);


    HTML_LOG(1,"dbg: scroll attributes [%s]",attr);

TRACE;
    if (*select) {

        cell_text = STRDUP(title);

    } else if (strcmp(newview,"tv") == 0 ) {
        // TV shows are drill down by title and season
        cell_text = get_tv_drilldown_link(newview,row_id->title,row_id->season,attr,title,font_class,cell_no_txt);

    } else if (util_starts_with(newview,"tv") ) {
        // Box sets or TV shows are drill down by title
        cell_text = get_tvboxset_drilldown_link(newview,row_id->title,attr,title,font_class,cell_no_txt);


    } else if (row_id->category == 'M') {
        // Movies are drill down by ID
        cell_text = get_movie_drilldown_link(newview,idlist,attr,title,font_class,cell_no_txt);



    } else {

TRACE;

        char cellId[9];

        sprintf(cellId,"%d",cell_no);
        char *cellName;
        if (selected_cell) {
            cellName="selectedCell";
        } else {
            cellName=cellId;
        }

        cell_text = vod_link(row_id,title,"",row_id->db->source,row_id->file,cellName,attr,font_class);

    }
    FREE(attr);

    if (*select) {
        char *tmp = cell_text;
        tmp=select_checkbox(row_id,cell_text);
        FREE(cell_text);
        cell_text=tmp;
    }


    // Add a horizontal image to stop cell shrinkage.
    char *add_spacer = "";
    if (in_poster_mode() && displaying_text) {
        ovs_asprintf(&add_spacer,"<br><img src=\"images/1h.jpg\" %s height=1px>",width_attr);
    }

    char *result;

    ovs_asprintf(&result,"\t<td %s%s class=grid%d %s >%s%s%s%s</td>\n",
            (cell_background_image?"background=":""),
            (cell_background_image?cell_background_image:""),

            //width_attr,
            //height_attr,
            grid_toggle,
            mouse_ev,
            
            cell_text,
            (first_space?" ":""),
            (first_space?first_space+1:""),
            add_spacer);

    if (add_spacer && *add_spacer) FREE(add_spacer);
    if (mouse_ev && *mouse_ev) FREE(mouse_ev);
    if (focus_ev && *focus_ev) FREE(focus_ev);
    if (cell_background_image && *cell_background_image) FREE(cell_background_image);

    FREE(cell_text);
    FREE(title); // first_space points inside of title
    return result;
}
char *get_tv_drilldown_link(char *view,char *name,int season,char *attr,char *title,char *font_class,char *cell_no_txt)
{
    static char *link_template = NULL;
    if (link_template == NULL ) {

        // Note the Selected parameter is added with a preceding @. This ensures that it is present in the 
        // return link. 
        link_template = get_drilldown_link_with_font(
            QUERY_PARAM_VIEW "=@VIEW@&p=&"QUERY_PARAM_REGEX"="NAME_FILTER_STRING_FLAG"@NAME@&"QUERY_PARAM_SEASON"=@SEASON@&@"QUERY_PARAM_SELECTED"=@CELLNO@",
            "@ATTR@","@TITLE@","@FONT_CLASS@");
    }
    char season_txt[9];
    sprintf(season_txt,"%d",season);

    return replace_all_str(link_template,
            "@VIEW@",view,
            "@NAME@",name,
            "@SEASON@",season_txt,
            "@ATTR@",attr,
            "@TITLE@",title,
            "@CELLNO@",cell_no_txt,
            "@FONT_CLASS@",font_class,
            NULL);
}

char *get_tvboxset_drilldown_link(char *view,char *name,char *attr,char *title,char *font_class,char *cell_no_txt)
{
    static char *link_template = NULL;
    if (link_template == NULL ) {

        // Note the Selected parameter is added with a preceding @. This ensures that it is present in the 
        // return link. 
        link_template = get_drilldown_link_with_font(
                QUERY_PARAM_VIEW "=@VIEW@&p=&"QUERY_PARAM_REGEX"="NAME_FILTER_STRING_FLAG"@NAME@&@"QUERY_PARAM_SELECTED"=@CELLNO@","@ATTR@","@TITLE@","@FONT_CLASS@");
    }

    return replace_all_str(link_template,
            "@VIEW@",view,
            "@NAME@",name,
            "@ATTR@",attr,
            "@TITLE@",title,
            "@FONT_CLASS@",font_class,
            "@CELLNO@",cell_no_txt,
            NULL);
}
char *get_movie_drilldown_link(char *view,char *idlist,char *attr,char *title,char *font_class,char *cell_no_txt)
{
    static char *link_template = NULL;
    if (link_template == NULL ) {

        // Note the Selected parameter is added with a preceding @. This ensures that it is present in the 
        // return link. 
        link_template = get_drilldown_link_with_font(
               QUERY_PARAM_VIEW "=@VIEW@&p=&idlist=@IDLIST@&@"QUERY_PARAM_SELECTED"=@CELLNO@","@ATTR@","@TITLE@","@FONT_CLASS@");
    }
    return replace_all_str(link_template,
            "@VIEW@",view,
            "@IDLIST@",idlist,
            "@ATTR@",attr,
            "@TITLE@",title,
            "@FONT_CLASS@",font_class,
            "@CELLNO@",cell_no_txt,
            NULL);
}

char *get_drilldown_view(DbRowId *rid) {

    DbRowId *rid2;
    char *view=NULL;

    switch (rid->category) {
        case 'T':
            view = VIEW_TV;
            break;
        case 'M': case 'F':
            view = VIEW_MOVIE;
            break;
        default:
            view = "unknown";
            break;
    }

    for( rid2=rid->linked ; rid2 ; rid2=rid2->linked ) {

        if (rid2->category != rid->category ) {
            view = VIEW_MIXED;
            break;
        } else {
            switch (rid2->category) {
                case 'T':
                    if (rid->season != rid2->season) {
                        view=VIEW_TVBOXSET;
                    }
                    break;
                case 'M': case 'F':
                    // As soon as there are two linked movies its a box set
                    // view=VIEW_MOVIEBOXSET;
                    break;
                default:
                    view=VIEW_MIXED;
                    break;
            }
        }
    }
    return view;
}

char *template_replace_only(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids);
int template_replace_and_emit(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids);

#define MACRO_STR_START "["
#define MACRO_STR_END "]"
#define MACRO_STR_START_INNER ":"
#define MACRO_STR_END_INNER ":"
int template_replace(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids) {

TRACE;

    // first replace simple variables in the buffer.
    char *newline=template_replace_only(template_name,input,num_rows,sorted_row_ids);
    if (newline != input) {
        HTML_LOG(2,"old line [%s]",input);
        HTML_LOG(2,"new line [%s]",newline);
    }
TRACE;
    // if replace complex variables and push to stdout. this is for more complex multi-line macros
    int count = template_replace_and_emit(template_name,newline,num_rows,sorted_row_ids);
TRACE;
    if (newline !=input) FREE(newline);
    return count;
}

char *template_replace_only(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids) {

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
            char *macro_output = macro_call(template_name,macro_name_start,num_rows,sorted_row_ids,&free_result);
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
TRACE;
    return newline;
}
int template_replace_and_emit(char *template_name,char *input,int num_rows,DbRowId **sorted_row_ids) {

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
TRACE;
            char *macro_output = macro_call(template_name,macro_name_start,num_rows,sorted_row_ids,&free_result);
TRACE;

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

char *scanlines_to_text(long scanlines) {
    switch(scanlines) {
        case 1080: return "1080";
        case 720: return "720";
        default: return "sd";
    }
}

void display_template(char*template_name,char *file_name,int num_rows,DbRowId **sorted_row_ids) {

    HTML_LOG(1,"begin template");

    char *file;

    ovs_asprintf(&file,"%s/templates/%s/%s/%s.template",appDir(),
            template_name,
            scanlines_to_text(g_dimension->scanlines),
            file_name);
    HTML_LOG(0,"opening %s",file);

    FILE *fp=fopen(file,"r");
    if (fp == NULL) {
        if (errno == 2 || errno == 22) {
            FREE(file);
            ovs_asprintf(&file,"%s/templates/%s/any/%s.template",appDir(),
                    template_name,
                    file_name);
            HTML_LOG(2,"opening %s",file);
            fp=fopen(file,"r");
        }
        if (fp == NULL) {
            html_error("Error %d opening %s",errno,file);
        }
    }

    if (fp) {
#define HTML_BUF_SIZE 999

        char buffer[HTML_BUF_SIZE+1];

        int is_css = util_starts_with(file_name,"css.") ;
        int fix_css_bug = is_css && is_local_browser();


        while(fgets(buffer,HTML_BUF_SIZE,fp) != NULL) {
            int count = 0; 
            buffer[HTML_BUF_SIZE] = '\0';
            char *p=buffer;
//            while(*p == ' ') {
//                p++;
//            }
            if ((count=template_replace(template_name,p,num_rows,sorted_row_ids)) != 0 ) {
                HTML_LOG(4,"macro count %d",count);
            }

            if (fix_css_bug && strstr(p,"*/") ) {
                printf(".dummy { color:blue; }");
            }

        }
        fflush(stdout);
        fclose(fp);
    }

    if (file) FREE(file);
    HTML_LOG(1,"end template");
}


int check_and_prune_item(DbRowId *rowid,char *path) {

    int result = 0;

    if (nmt_mount(path) ) {

        if (exists(path) ) {

            result = 1;

        } else {

        }
    }
    return result;
}

// Delist a file if it's grandparent folder is present and not empty.
// This is deleted from the db, which will be reflected in the next page draw.
int delisted(DbRowId *rowid)
{

    int freepath;
    char *path = get_path(rowid,rowid->file,&freepath);
    int result = 0;
    static int auto_prune=-2;
    if (auto_prune == -2) {
        auto_prune = *oversight_val("ovs_auto_prune") == '1';
        HTML_LOG(0,"auto delist = %d",auto_prune);
    }

    HTML_LOG(1,"auto delist precheck [%s]",path);
    if (auto_prune && !exists(path)) {
        
        HTML_LOG(0,"auto delist check [%s][%s]",rowid->db->source,path);

        char *parent_dir = util_dirname(path);
        char *grandparent_dir = util_dirname(parent_dir);

        char *name = util_basename(path);

        HTML_LOG(1,"path[%s]",path);
        HTML_LOG(1,"parent_dir[%s]",parent_dir);
        HTML_LOG(1,"grandparent_dir[%s]",grandparent_dir);
        HTML_LOG(1,"grandparent_dir[%s] exists = %d",grandparent_dir,exists(grandparent_dir));
        HTML_LOG(1,"name[%s]",name);

        if (exists(grandparent_dir) && !is_empty_dir(grandparent_dir) &&  auto_prune) {

            //media present - file gone!
            db_remove_row(rowid);
            result = 1;

        }
        FREE(name);
        FREE(parent_dir);
        FREE(grandparent_dir);
    }
    HTML_LOG(1-result,"delisted [%s] = %d",path,result);
    if (freepath) FREE(path);
    return result;
}

// Return 1 if this row and all of its linked items are delisted.
int all_linked_rows_delisted(DbRowId *rowid)
{
    DbRowId *r;

    for(r = rowid ; r != NULL ; r = r->linked) {
        if (!delisted(r)) {
            return 0;
        }
    }
    return 1;
}

void write_titlechanger(int rows, int cols, int numids, DbRowId **row_ids,char **idlist) {
    int i,r,c;

    HTML_LOG(0,"script start");
    printf("<script type=\"text/javascript\"><!--\n");

    for ( r = 0 ; r < rows ; r++ ) {
        for ( c = 0 ; c < cols ; c++ ) {
            i = c * rows + r ;
            if ( i < numids ) {

                DbRowId *rid = row_ids[i];

                int watched,unwatched;
                get_watched_counts(rid,&watched,&unwatched);

                char *title = get_simple_title(rid,NULL);
                if (rid->category == 'T' ) {
                    // Write the call to the show function and also tract the idlist;
                    printf("function " JAVASCRIPT_MENU_FUNCTION_PREFIX "%x() { showt('%s','%s',%d,%d); }\n",
                            i+1,title,idlist[i],
                            unwatched,
                            watched
                            );
                } else {
                    // Write the call to the show function and also tract the idlist;
                    printf("function " JAVASCRIPT_MENU_FUNCTION_PREFIX "%x() { showt('%s','%s','-','-'); }\n",
                            i+1,title,idlist[i]);
                }
                FREE(title);
            }
        }
    }
    printf("--></script>\n");
    HTML_LOG(0,"script end");
}

// Generate the HTML for the grid. 
// Note that the row_ids have already been pruned to only contain the items
// for the current page.
char *render_grid(long page,int rows, int cols, int numids, DbRowId **row_ids,int page_before,int page_after) {
    
    int end = numids;
    int centre_row = rows/2;
    int centre_col = cols/2;
    int r,c;

    char *table_start,*table_end;
    char *table_id;

    int cell_margin=2;

    if (g_dimension->poster_mode) {
        ovs_asprintf(&table_id,"<table class=overview_poster >");
            //ovs_asprintf(&table_id,"<table class=overview_poster height=%dpx>",
            //               2*(g_dimension->poster_menu_img_height+cell_margin));
    } else {
        ovs_asprintf(&table_id,"<table class=overview_poster width=100%%>");
    }

   table_start = table_id;
   table_end = "</table>";

    if (end > numids) end = numids;

    HTML_LOG(0,"render page %ld rows %d cols %d",page,rows,cols);

#if 0
    HTML_LOG(0,"input size = %d",numids);
    for(r=0 ; r<numids ; r++) {
        HTML_LOG(0,"get_grid row %d %s %s %s",r,row_ids[r]->db->source,row_ids[r]->title,row_ids[r]->file);
        DbRowId *l =row_ids[r]->linked;
        while (l) {
            HTML_LOG(0,"get_grid linked %d %s %s %s",r,l->db->source,l->title,l->file);
           l = l->linked;
        }
    }
#endif


    char *result=NULL;
    int i;
    char *width_attr;
    char *height_attr;
    char *tmp;

    if (numids < rows * cols ) {
        //re-arrange layout to have as many columns as possible.
        rows = (numids + (cols-1)) / cols;
    }

    if (g_dimension->poster_mode) {
        ovs_asprintf(&width_attr," width=%dpx ", g_dimension->poster_menu_img_width+cell_margin);

        ovs_asprintf(&height_attr," height=%dpx ", g_dimension->poster_menu_img_height+cell_margin);
    } else {
        ovs_asprintf(&width_attr," width=%d%% ",(int)(100/cols));
        height_attr=STRDUP("");
    }

    char **idlist = CALLOC(rows*cols,sizeof(char *));

    // Create the idlist for each item
    for ( r = 0 ; r < rows ; r++ ) {
        for ( c = 0 ; c < cols ; c++ ) {
            i = c * rows + r ;
            if (i < numids) {
                idlist[i] = build_id_list(row_ids[i]);
            }
        }
    }

    // First output the javascript functions - diretly to stdout - lazy.
    write_titlechanger(rows,cols,numids,row_ids,idlist);

    Array *rowArray = array_new((void(*)(void *))array_free);

    int selected_cell = -1;
    if (*get_selected_item()) {
        selected_cell = atol(get_selected_item());
    } else {
        selected_cell = centre_col * rows + centre_row;
    }
    

    // Now build the table and return the text.
    for ( r = 0 ; r < rows ; r++ ) {

        HTML_LOG(0,"grid row %d",r);
        ovs_asprintf(&tmp,"%s<tr class=\"grid_row%d\" >\n",(result?result:""),(r&1));

        Array *cellArray = array_new(free);
        array_add(cellArray,tmp);

        for ( c = 0 ; c < cols ; c++ ) {
            i = c * rows + r ;

            HTML_LOG(1,"grid col %d",c);

            int left_scroll = (page_before && c == 0);
            int right_scroll = (page_after && c == cols-1 );
            int is_selected = (i == selected_cell);

            char *item=NULL;
            if ( i < numids ) {
                item = get_item(i,row_ids[i],(c+r)&1,width_attr,height_attr,left_scroll,right_scroll,is_selected,idlist[i]);
            } else {
                // only draw empty cells if there are two or more rows
                if (rows > 1) {
                    item = get_empty(width_attr,(c+r)&1,height_attr,left_scroll,right_scroll,is_selected);
                } else {
                    item = NULL;
                }

            }

            if (item) array_add(cellArray,item);
            HTML_LOG(1,"grid end col %d",c);
        }

        array_add(cellArray,STRDUP("</tr>\n"));
        array_add(rowArray,cellArray);
        HTML_LOG(0,"grid end row %d",r);

    }
    //
    // Free all of the idlists
    util_free_char_array(rows*cols,idlist);

    char *w;
    if (!g_dimension->poster_mode) {
        w="width=100%";
    } else {
        w="";
    }

    result = array2dstr(rowArray);
    array_free(rowArray);

    ovs_asprintf(&tmp,"<center>%s\n%s\n%s</center>\n",
            table_start,
            (result?result:"<tr><td>No results</td><tr>"), //bug here may need to add table tags
             table_end
    );
    FREE(table_id);
    FREE(result);
    result=tmp;

    FREE(width_attr);
    return result;
}


char *get_grid(long page,int rows, int cols, int numids, DbRowId **row_ids) {
    // first loop through the selected rowids that we expect to draw.
    // If there are any that need pruning - remove them from the database and get another one.
    // This will possibly cause a temporary inconsistency in page numbering but
    // as we have just updated the database it will be correct on the next page draw.
    //
    // Note the db load routing should already filter out items that cant be mounted,
    // otherwise this can cause timeouts.
    int items_per_page = rows * cols;
    int start = page * items_per_page;

    int total=0;
    // Create space for pruned rows
    HTML_LOG(0,"get_grid page %ld rows %d cols %d",page,rows,cols);
    DbRowId **prunedRows = filter_delisted(start,numids,row_ids,items_per_page,&total);
    HTML_LOG(0,"pruned");
    
    int page_before = (page > 0);
    int page_after = (numids >= total);
    return render_grid(page,rows,cols,total,prunedRows,page_before,page_after);
}


/* Convert 234 to TVID/text message regex */
char *get_tvid( char *sequence ) {
    char *out = NULL;
    char *p,*q;
    if (sequence) {
        out = p = MALLOC(9*strlen(sequence)+1);
        *p = '\0';
        for(q = sequence ; *q ; q++ ) {
            switch(*q) {
                case '1' : strcpy(p,"1"); break;
                case '2' : strcpy(p,"[2abc]"); break;
                case '3' : strcpy(p,"[3def]"); break;
                case '4' : strcpy(p,"[4ghi]"); break;
                case '5' : strcpy(p,"[5jkl]"); break;
                case '6' : strcpy(p,"[6mno]"); break;
                case '7' : strcpy(p,"[7pqrs]"); break;
                case '8' : strcpy(p,"[8tuv]"); break;
                case '9' : strcpy(p,"[9wxyz]"); break;
            }
            p += strlen(p);
        }
    }
    HTML_LOG(2,"tvid %s = regex %s",sequence,out);
    return out;

}

char *default_button_attr() {
    static char *default_attr = NULL;
    if (default_attr == NULL) {
        ovs_asprintf(&default_attr,"width=%ld height=%ld",g_dimension->button_size,g_dimension->button_size);
        HTML_LOG(1,"default button attr = %s",default_attr);
    }
    return default_attr;
}

char *skin_name()
{
    static char *template_name=NULL;
    if (!template_name) template_name=oversight_val("ovs_skin_name");
    return template_name;
}

char *icon_source(char *image_name)
{

    char *path;
    assert(image_name);
    static int is_default_skin = UNSET;
    if (is_default_skin == UNSET) {
        is_default_skin = (strcmp(skin_name(),"default") == 0);
    }

    char *ico=ovs_icon_type();

    ovs_asprintf(&path,"%s/templates/%s/images/%s.%s",
            appDir(),
            skin_name(),
            image_name,
            ico);

    if (!exists(path) && !is_default_skin) {
        FREE(path);
        ovs_asprintf(&path,"%s/templates/default/images/%s.%s",
                appDir(),
                image_name,
                ico);
    }

    char *result = file_to_url(path);
    FREE(path);
    return result;
}

void href(char *url,char *attr,char *text) {
    printf("\n<a href=\"%s\" %s>%s</a>",url,attr,text);
}

char *get_theme_image_tag(char *image_name,char *attr) {

    char *isrc;
    char *result = NULL;
    assert(image_name);
    if (attr == NULL || ! *attr) {

        attr = default_button_attr();
    }
    isrc = icon_source(image_name);
    ovs_asprintf(&result,"<img alt=\"%s\" border=0 src=%s %s />",image_name,isrc,attr);
    FREE(isrc);
    return result;
}



int get_sorted_rows_from_params(DbRowSet ***rowSetsPtr,DbRowId ***sortedRowsPtr) {


    // Get filter options
    long crossview=0;

    config_check_long(g_oversight_config,"ovs_crossview",&crossview);
    HTML_LOG(1,"Crossview = %ld",crossview);

    //Tvid filter = this as the form 234
    HTML_LOG(0,"begin hdump");
    html_hashtable_dump(0,"query",g_query);
    HTML_LOG(0,"end hdump");

TRACE;

    int free_regex=0;
    char *regex = query_val(QUERY_PARAM_REGEX);

    if (EMPTY_STR(regex)) {
TRACE;
        //Check regex entered via text box

        if (*query_val("searcht") && *query_val(QUERY_PARAM_SEARCH_MODE)) {
            regex=util_tolower(query_val("searcht"));
            free_regex=1;
        }
    }
TRACE;
    HTML_LOG(0,"Regex filter = %s",regex);

    // Watched filter
    // ==============
    int watched = DB_WATCHED_FILTER_ANY;
TRACE;
    char *watched_param=query_val(QUERY_PARAM_WATCHED_FILTER);

TRACE;
    if (strcmp(watched_param,QUERY_PARAM_WATCHED_VALUE_YES) == 0) {
TRACE;

        watched=DB_WATCHED_FILTER_YES;

    } else if (strcmp(watched_param,QUERY_PARAM_WATCHED_VALUE_NO) == 0) {
TRACE;

        watched=DB_WATCHED_FILTER_NO;
    }

TRACE;
    HTML_LOG(1,"Watched filter = %ld",watched);

    // Tv/Film filter
    // ==============
    char *media_type_str=query_val(QUERY_PARAM_TYPE_FILTER);
    int media_type=DB_MEDIA_TYPE_ANY;

    if(strcmp(media_type_str,QUERY_PARAM_MEDIA_TYPE_VALUE_TV) == 0) {
TRACE;

        media_type=DB_MEDIA_TYPE_TV; 

    } else if(strcmp(media_type_str,QUERY_PARAM_MEDIA_TYPE_VALUE_MOVIE) == 0) {
TRACE;

        media_type=DB_MEDIA_TYPE_FILM; 

    }
    HTML_LOG(1,"Media type = %d",media_type);

TRACE;
    
    DbRowSet **rowsets = db_crossview_scan_titles( crossview, regex, media_type, watched);

TRACE;

    if (free_regex) { FREE(regex); }

    struct hashtable *overview = db_overview_hash_create(rowsets);
TRACE;

    DbRowId **sorted_row_ids = NULL;
    
    char *sort = DB_FLDID_TITLE;

    config_check_str(g_query,QUERY_PARAM_SORT,&sort);
    int numrows = hashtable_count(overview);
TRACE;

    if (strcmp(query_val(QUERY_PARAM_VIEW),VIEW_TV) == 0) {
TRACE;

        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_title);

    } else  if (sort && strcmp(sort,DB_FLDID_TITLE) == 0) {
TRACE;

        HTML_LOG(1,"sort by name [%s]",sort);
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_title);

    } else {
TRACE;

        HTML_LOG(1,"sort by age [%s]",sort);
        sorted_row_ids = sort_overview(overview,db_overview_cmp_by_age);
    }
TRACE;

    //Free hash without freeing keys
    db_overview_hash_destroy(overview);

    if (sortedRowsPtr) *sortedRowsPtr = sorted_row_ids;
    if (rowSetsPtr) *rowSetsPtr = rowsets;

    return numrows;
}

typedef struct tvid_struct {
    char *sequence;
    char *range;
} Tvid ;

#define TVID_MAX_LEN 2 //
#define TVID_MAX 99  //must be 10 ^ TVID_MAX_LEN -1
char *get_tvid_links() {

    // Pre compute format string for tvids.
#define TVID_MARKER "@X@Y@"
    char *params;
    ovs_asprintf(&params,"idlist=&p=0&"QUERY_PARAM_TITLE_FILTER"=%s",TVID_MARKER);

    char *format_string = get_self_link(params,"tvid=\""TVID_MARKER"\"","");
    FREE(params);

    //As we want a printf format string - escape any %
    if (strchr(format_string,'%') ) {
        char *tmp = replace_all(format_string,"%","%%",0);
        FREE(format_string);
        format_string=tmp;
    }
    int format_memsize = strlen(format_string)+20;

    char *tmp = replace_all(format_string,TVID_MARKER,"%s",0);
    FREE(format_string);
    format_string=tmp;

//    HTML_LOG(0,"Format string [%s]",format_string);


    char *result = NULL;
    Tvid list[]={
        {"0","*"} , {"11","*"} , // reset
        {"1","1"} ,  // db scan will get all non-alpha if this parameter is < A
        {"2","A"} , {"22","B"} , {"222","C"} ,
        {"3","D"} , {"33","E"} , {"333","F"} ,
        {"4","G"} , {"44","H"} , {"444","I"} ,
        {"5","J"} , {"55","K"} , {"555","L"} ,
        {"6","M"} , {"66","N"} , {"666","O"} ,
        {"7","P"} , {"77","Q"} , {"777","R"} , {"7777","S"} ,
        {"8","T"} , {"88","U"} , {"888","V"} ,
        {"9","W"} , {"99","X"} , {"999","Y"} , {"9999","Z"} ,
        { NULL,NULL} } ;

    // Get size of array - probably a better C way.
    int i;
    for ( i = 0 ; list[i].sequence ; i++ ) {
//        HTML_LOG(0,"tvid = %s/%s",list[i].sequence,list[i].range);
        continue;
    }
    HTML_LOG(0,"size = %d",i);

    result = CALLOC(i,format_memsize);

    char *p = result;
    for ( i = 0 ; list[i].sequence ; i++ ) {
        p += sprintf(p,format_string,list[i].range,list[i].sequence);
        *(p++) = '\n';
        *p='\0';
    }
//    HTML_LOG(0,"result = %s",result);

    return result;
}

long use_boxsets() {
    static long boxsets = -1;
    if(boxsets == -1) {
        if (!config_check_long(g_oversight_config,"ovs_tvboxsets",&boxsets)) {
            boxsets = 0;
        }
    }
    return boxsets;
}

void build_playlist(int num_rows,DbRowId **sorted_rows)
{
    int i;
    FILE *fp = NULL;
    for(i = 0 ; i < num_rows ; i++ ) {
        DbRowId *rowid = sorted_rows[i];
        if (rowid->playlist_names && rowid->playlist_paths) {
            int j;
            HTML_LOG(0,"Adding files for [%s] to playlist",rowid->title);
            assert(rowid->playlist_names->size == rowid->playlist_paths->size);
            for(j = 0 ; j < rowid->playlist_names->size ; j++ ) {

                char *name = rowid->playlist_names->array[j]; 
                char *path = rowid->playlist_paths->array[j]; 
                HTML_LOG(0,"Adding [%s] to playlist",path);

                if (fp == NULL) fp = playlist_open();
                fprintf(fp,"%s|0|0|file://%s|",name,path);
                fflush(fp);
            }
        }
    }
    if (fp) {
        fclose(fp);
    }
}



// Add a javascript function to return a plot string.
// returns number of characters in javascript.
char *ep_js_fn(char *script_so_far,long fn_id,char *idlist,char *episode,char *plot,char *info,char *eptitle_or_genre,char *date,char *share) {
    char *result = NULL;

    char *js_plot = clean_js_string(plot);
    char *js_info = clean_js_string(info);
    char *js_eptitle = clean_js_string(eptitle_or_genre);
    char *js_date = clean_js_string(date);
    char *episode_prefix = "";
    if (!EMPTY_STR(episode) && !util_starts_with(episode,"DVD")) {
        episode_prefix="Episode ";
    }

    ovs_asprintf(&result,"%sfunction " JAVASCRIPT_EPINFO_FUNCTION_PREFIX "%lx() { show('%s','%s%s','%s','%s','%s%s%s%s%s'); }\n",
            NVL(script_so_far),fn_id,
                idlist,
                episode_prefix,
                episode,
                IFEMPTY(js_plot,"(no plot info)"),
                js_info,
                NVL(js_eptitle),NVL(js_date),
                (share?" [":""),NVL(share),(share?"]":""));

    if (js_plot != plot) FREE(js_plot);
    if (js_info != info) FREE(js_info);
    if (js_eptitle != eptitle_or_genre) FREE(js_eptitle);
    if (js_date != date) FREE(js_date);

    return result;
}

void util_free_char_array(int size,char **a)
{
    int i;
    for(i = 0 ; i < size ; i++ ) {
        FREE(a[i]);
    }
    FREE(a);
}

char *best_eptitle(DbRowId *rid,int *free_title) {

    *free_title=0;
    char *title=rid->eptitle;
    if (title == NULL || !*title) {
        title=rid->eptitle_imdb;
    }
    if (title == NULL || !*title) {
        title=rid->additional_nfo;
    }
    if (title == NULL || !*title) {
        title=util_basename(rid->file);
        *free_title=1;
    }
    return title;
}

/**
 * Create a number of javascript functions that each return the 
 * plot for a given row.
 * The funtions are named using the address location of the data  structure.
 * eg plot12234() { return 'He came, he saw , he conquered'; }
 */
char *create_episode_js_fn(int num_rows,DbRowId **sorted_rows) {

    char *result = NULL;

    int i;
    char *tmp;

TRACE;
    // get titles from plot.db
    get_plot_offsets_and_text(num_rows,sorted_rows,1);

TRACE;
    // build the idlist
    char **idlist = CALLOC(num_rows,sizeof(char *));
    for(i = 0 ; i < num_rows ; i++ ) {
        idlist[i] = build_id_list(sorted_rows[i]);
    }
TRACE;

    // Find the first plot and genre
    char *main_plot=NULL;
    char *main_genre=NULL;

    for(i = 0 ; i < num_rows ; i++ ) {
        DbRowId *rid = sorted_rows[i];
        if (EMPTY_STR(main_plot) && !EMPTY_STR(rid->plottext[PLOT_MAIN])) {
            main_plot = rid->plottext[PLOT_MAIN];
        }
        if (EMPTY_STR(main_genre) && !EMPTY_STR(rid->genre)) {
            main_genre = rid->genre;
        }
    }

    if (EMPTY_STR(main_plot)) main_plot = "(no plot info)";
    if (main_genre == NULL) {
        main_genre = STRDUP("no genre");
    } else {
        main_genre = expand_genre(main_genre);
    }

TRACE;

    tmp = ep_js_fn(result,0,"","",NVL(main_plot),"",NVL(main_genre),NULL,NULL);
    FREE(main_genre);
    FREE(result);
    result = tmp;

HTML_LOG(0,"num rows = %d",num_rows);
    // Episode Plots
    for(i = 0 ; i < num_rows ; i++ ) {
        DbRowId *rid = sorted_rows[i];
        char *date = get_date_static(rid);
        int free_title=0;
        char *title = best_eptitle(rid,&free_title);

        int freeshare=0;
        char *share = share_name(rid,&freeshare);

        tmp = ep_js_fn(result,i+1,idlist[i],NVL(rid->episode),NVL(rid->plottext[PLOT_EPISODE]),rid->file,title,date,share);
        FREE(result);
        if (free_title) FREE(title);
        if (freeshare) FREE(share);
        result = tmp;

    }

    ovs_asprintf(&tmp,"<script type=\"text/javascript\"><!--\n%s\n--></script>\n",result);
    FREE(result);
    result = tmp;

TRACE;
    util_free_char_array(num_rows,idlist);
TRACE;

    return result;
}

char *get_date_static(DbRowId *rid)
{
    static char *old_date_format=NULL;
    static char *recent_date_format=NULL;
    // Date format
    if (recent_date_format == NULL && !config_check_str(g_oversight_config,"ovs_date_format",&recent_date_format)) {
        recent_date_format=" - %d %b";
    }
    if (old_date_format == NULL && !config_check_str(g_oversight_config,"ovs_old_date_format",&old_date_format)) {
        old_date_format=" -%d %b %y";
    }

#define DATE_BUF_SIZ 40
    static char date_buf[DATE_BUF_SIZ];


    OVS_TIME date=rid->airdate;
    if (date<=0) {
        date=rid->airdate_imdb;
    }
    *date_buf='\0';
    if (date > 0) {

        char *date_format=NULL;
        if  (year(epoc2internal_time(time(NULL))) != year(date)) {  
            date_format = old_date_format;
        } else {
            date_format = recent_date_format;
        }

        strftime(date_buf,DATE_BUF_SIZ,date_format,internal_time2tm(date,NULL));
    }
    return date_buf;
}

DbRowId **filter_delisted(int start,int num_rows,DbRowId **row_ids,int max_new,int *new_num)
{

    int i;
    int total = 0;

    DbRowId **new_list = CALLOC(max_new+1,sizeof(DbRowId *));

    for ( i = start ; total < max_new && i < num_rows ; i++ ) {
        DbRowId *rid = row_ids[i];
        if (rid) {
            if (!all_linked_rows_delisted(rid)) {
                new_list[total++] = rid;
            }
        }
    }
    *new_num = total;
    return new_list;
}

char *pruned_tv_listing(int num_rows,DbRowId **sorted_rows,int rows,int cols)
{
    int r,c;

    char *select=query_val("select");

    char *listing=NULL;

    int width_txt_and_date=100/cols; //text and date
    int width_epno=1; //episode width
    int width_icon=1; //episode width
    width_txt_and_date -= width_epno+width_icon;

TRACE;
    HTML_LOG(0,"pruned_tv_listing");


TRACE;
    char *script = create_episode_js_fn(num_rows,sorted_rows);
TRACE;

    int show_episode_titles = *query_val(QUERY_PARAM_EPISODE_TITLES) == '1';
    int show_episode_dates = *query_val(QUERY_PARAM_EPISODE_DATES) == '1';
    if  (!show_episode_dates && !show_episode_titles ) {
        width_txt_and_date = 1;
    }

    int show_repacks = *oversight_val("ovs_show_repack") != '0';
    

    printf("%s",script);

    HTML_LOG(0,"pruned_tv_listing num_rows=%d r%d x c%d",num_rows,rows,cols);
    // Adjust rows to be squarish.
    if (num_rows/cols < rows ) {
        rows = (num_rows+cols-1) / cols;
    }

    HTML_LOG(0,"pruned_tv_listing num_rows=%d r%d x c%d",num_rows,rows,cols);
    for(r=0 ; r < rows ; r++ ) {
        HTML_LOG(1,"tvlisting row %d",r);
        char *row_text = NULL;
        for(c = 0 ; c < cols ; c++ ) {
            HTML_LOG(1,"tvlisting col %d",c);

            //int i = c * rows + r;
            int i = r * cols + c;
            if (i < num_rows) {

                int function_id = i+1;
                char *episode_col = NULL;

                DbRowId *rid = sorted_rows[i];

                if (*select) {
                    episode_col = select_checkbox(
                            rid,
                            rid->episode);
                } else {
                    char *ep = rid->episode;
                    if (ep == NULL || !*ep ) {
                        ep = "play";
                    }
                    char *href_attr = focus_event_fn(JAVASCRIPT_EPINFO_FUNCTION_PREFIX,function_id,1);
                    episode_col = vod_link(
                            rid,
                            ep,"",
                            rid->db->source,
                            rid->file,
                            ep,
                            NVL(href_attr),
                            watched_style(rid));
                    FREE(href_attr);
                }

                int free_eptitle=0;
                char *episode_title = "";
                if (show_episode_titles) {
                    episode_title = best_eptitle(rid,&free_eptitle);
                }

                char *title_txt=NULL;

                int is_proper = show_repacks && (strstr(rid->file,"proper") ||
                                 strstr(rid->file,"Proper") ||
                                 strstr(rid->file,"PROPER"));

                int is_repack = show_repacks && (strstr(rid->file,"repack") ||
                                 strstr(rid->file,"Repack") ||
                                 strstr(rid->file,"REPACK"));

                char *icon_text = icon_link(rid->file);

                ovs_asprintf(&title_txt,"%s%s%s",
                        episode_title,
                        (is_proper?"&nbsp;<font class=proper>[pr]</font>":""),
                        (is_repack?"&nbsp;<font class=repack>[rpk]</font>":"")
                        );
                if (free_eptitle) {
                    FREE(episode_title);
                }


                //Date
                char *date_buf=get_date_static(rid);


                //network icon
                char *network_icon = add_network_icon(rid,"");

                //Put Episode/Title/Date together in new cell.
                char td_class[10];
                sprintf(td_class,"ep%d%d",rid->watched,i%2);
                char *tmp;

                char *td_plot_attr = mouse_event_fn(JAVASCRIPT_EPINFO_FUNCTION_PREFIX,function_id,1);

                ovs_asprintf(&tmp,
                        "%s<td class=%s width=%d%% %s align=right>%s</td>" 
                        "<td width=%d%% %s>%s</td>"
                        "<td class=%s width=%d%% %s>"
                        "<font %s>%s%s</font>"
                        "<font class=epdate>%s</font></td>\n",
                        (row_text?row_text:""),
                        td_class,width_epno, td_plot_attr, episode_col,

                        width_icon,td_plot_attr,NVL(icon_text),

                        td_class, width_txt_and_date, td_plot_attr,

                        watched_style(rid), (network_icon?network_icon:""),
                        title_txt,
                        (show_episode_dates && *date_buf?date_buf:"")
                        );
                FREE(icon_text);
                FREE(td_plot_attr);
                FREE(title_txt);
                FREE(episode_col);
                FREE(row_text);
                row_text=tmp;

            } else {
                char *tmp=NULL;
                ovs_asprintf(&tmp,"%s<td width=%d%%></td><td width=%d%%></td><td width=%d%%></td>\n",
                    (row_text?row_text:""),
                    width_epno,
                    width_icon,
                    width_txt_and_date);
                FREE(row_text);
                row_text=tmp;
            }
        }
        // Add the row
        if (row_text) {
            char *tmp;
            ovs_asprintf(&tmp,"%s<tr align=top>%s</tr>\n",(listing?listing:""),row_text);
            FREE(row_text);
            FREE(listing);
            listing=tmp;
        }
    }


    char *result=NULL;
    ovs_asprintf(&result,"<table width=100%% class=listing onblur=\"tv_inf0();\" >%s</table>",listing);
    FREE(listing);
    return result;
}

char *tv_listing(int num_rows,DbRowId **sorted_rows,int rows,int cols)
{
    int pruned_num_rows;
    DbRowId **pruned_rows;


    html_log(-1,"tv_listing");
    pruned_rows = filter_delisted(0,num_rows,sorted_rows,num_rows,&pruned_num_rows);
    char *result = pruned_tv_listing(pruned_num_rows,pruned_rows,rows,cols);
    FREE(pruned_rows);

    return result;
}

char *get_status() {
    char *result=NULL;
#define MSG_SIZE 20
    static char msg[MSG_SIZE+1];
    char *filename;
    ovs_asprintf(&filename,"%s/catalog.status",appDir());

    msg[0] = '\0';

    FILE *fp = fopen(filename,"r");
    if (fp) {
        fgets(msg,MSG_SIZE,fp);
        msg[MSG_SIZE] = '\0';
        chomp(msg);

        result = STRDUP(msg);

        fclose(fp);
    } else {
        HTML_LOG(1,"Error %d opening [%s]",errno,filename);
    }
    FREE(filename);

    if (result == NULL) {

        if (exists_file_in_dir(tmpDir(),"cmd.pending")) {
            result = STRDUP("Scanning...");
        } else if (db_full_size() == 0 ) {
            result = STRDUP("No Videos indexed. In [Setup] select media sources and rescan.");
        }
    }

    return result;
}

char *auto_option_list(char *name,char *firstItem,struct hashtable *vals) {

    static char *attr = NULL;
    if (attr == NULL ) {
        if (g_dimension->local_browser) {
            ovs_asprintf(&attr,
            // Note the gaya path requires the full script name here. 
            // This becomes /HARD_DISK/Apps/oversight/oversight.cgi
            "onchange=\"location.assign('%s'+this.childNodes[this.selectedIndex].value)\"", getenv("SCRIPT_NAME"));
        } else {
            attr="onchange=\"location.assign(this.options[this.selectedIndex].value)\"";
        }
    }
    return option_list(name,attr,firstItem,vals);
}


#define PLACEHOLDER "@x@x@"
char *option_list(char *name,char *attr,char *firstItem,struct hashtable *vals) {
    char *result=NULL;
    char *selected=query_val(name);
    char *params;

    // Do not take ownership of the keys - thay belong to the hashtable.
    Array *keys = util_hashtable_keys(vals,0);
    array_sort(keys,array_strcasecmp);

    ovs_asprintf(&params,"p=&idlist=&%s=" PLACEHOLDER,name);
    char *link=self_url(params);
    FREE(params);
    Array *link_parts = splitstr(strchr(link,'?'),PLACEHOLDER);
    FREE(link);

    //GAYA does seem to like passing just the options to the link
    //eg just "?a=b"
    //we have to pass a more substantial path. eg. .?a=b

    if (keys && keys->size) {
        int i;


        for(i = 0 ; i < keys->size ; i++ ) {
            char *tmp;
            char *k=keys->array[i];
            char *v=hashtable_search(vals,k);
            char *link=join(link_parts,k);

            char *selected_text=(strcmp(selected,k)==0?"selected":"");

            if (firstItem != NULL && strcmp(firstItem,k) == 0 ) {
                // Add item to the start
                ovs_asprintf(&tmp,
                    "<option value=\"%s\" %s >%s</option>\n%s",
                    link, selected_text, v, NVL(result));
            } else {
                // Add item to the end
                ovs_asprintf(&tmp,
                    "%s<option value=\"%s\" %s >%s</option>\n",
                    NVL(result), link, selected_text, v);
            }
            FREE(link);
            FREE(result);
            result=tmp;
        }
    }
    if (result) {
        char *tmp;
        ovs_asprintf(&tmp,"<select %s>\n%s</select>",
                //name,
                attr, result);
        FREE(result);
        result = tmp;
    }
    array_free(link_parts);
    array_free(keys);
    return result;
}

void xx_dump_genre(char *file,int line,int num,DbRowId **rows) {
    int i;
    HTML_LOG(0,"xx genre dump [%s:%d] num=%d",file,line,num);
    for(i = 0 ; i < num ; i++ ) {
        DbRowId *rid = rows[i];
        HTML_LOG(0,"%d[%s][%s]",rid->id,rid->title,rid->genre);
    }
}

// Remove and store the last navigation cell. eg if user clicked on cell 12 this is passed in 
// the URL as @i=12. The url that returns to this page then has i=12. If we have returned to this
// page we must remove i=12 from the query so that it is not passed to the new urls created for this 
// page.
static char *selected_item = NULL;
void set_selected_item()
{
    if (selected_item == NULL) {
        selected_item = STRDUP(query_val(QUERY_PARAM_SELECTED));
        query_remove(QUERY_PARAM_SELECTED);
    }
}
char *get_selected_item()
{
    assert(selected_item);
    return selected_item;
}
