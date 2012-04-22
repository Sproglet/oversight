// $Id:$
//
// Yamj emulation
//
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <utime.h>
#include <errno.h>
#include <stdio.h>
#include <regex.h>
#include <assert.h>
#include <string.h>
#include <dirent.h>
#include <time.h>
#include <ctype.h>

#include "types.h"
#include "yamj.h"
#include "db.h"
#include "dbitem.h"
#include "dbnames.h"
#include "dboverview.h"
#include "dbplot.h"
#include "actions.h"
#include "dbfield.h"
#include "gaya_cgi.h"
#include "oversight.h"
#include "hashtable_loop.h"
#include "network.h"
#include "mount.h"
#include "abet.h"

#define CONFIG_PREFIX "ovs_yamj_cat"
#define CATEGORY_INDEX "Categories.xml"
#define YAMJ_THUMB_PREFIX "thumb_"
#define YAMJ_POSTER_PREFIX "poster_"
#define YAMJ_FANART_PREFIX "fanart_"

// Prototypes
void add_static_indices_to_item(DbItem *item,YAMJSubCat *selected_subcat,Array *categories);

/*
 * The plan is as follows:
 *
 * All YAML Xml category files contain information on all other categories. This is so that skins have 
 * visibility of all information to build menus, in a single file.
 *
 * So:
 * yamj_build_categories will load ALL of the categories from the config file.
 * For the particular category and page no passed as argments, oversight will filter the database (This is the 
 * based on get_sorted_rows_from_params() function. in particular:
 *
 *     Exp *query_exp = build_filter(media_types);
 *     // Get array of rowsets. One item for each database source. 
 *     DbItemSet **rowsets = db_crossview_scan_titles( crossview, query_exp);
 *
 *    The contents of rowsets corresponds to all matching items.
 *
 * After this some extra work will be required to create the AutoBox Sets from the SET field.
 *
 *
 * Expected inputs - note that Movies and Categories share the same namespace (folder) 
 *
 * /yamj/CategoryName_SubCategoryName_Page.xml
 * /yamj/MovieBaseName.xml
 * /yamj/MovieBaseName.jpg
 * /yamj/MovieBaseName-fanart.jpg
 *
 * Example Categories:
 * /yamj/Title_A_1.xml
 * /yamj/Set_Show_Season1_1.xml
 *
 * Eg.
 */

void xml_headers()
{
    printf("%s%s\n\n",CONTENT_TYPE,"application/xml");
    printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n");
}

void free_yamj_subcatetory(void *in)
{
    if (in) {
        YAMJSubCat *ptr = in;
        FREE(ptr->name);
        FREE(ptr->filter_expr_url);
        exp_free(ptr->filter_expr,1);
        FREE(ptr);
    }
}

void free_yamj_catetory(void *in)
{
    if (in) {
        YAMJCat *ptr = in;
        FREE(ptr->name);
        FREE(ptr->auto_subcat_expr_url);
        exp_free(ptr->auto_subcat_expr,1);
        array_free(ptr->subcats);
        FREE(ptr);
    }
}


YAMJSubCat *new_subcat(YAMJCat *owner,char *name,char *filter_url,int require_filter,int alert_duplicate)
{

    assert(owner);
    YAMJSubCat *ret = NULL;

    // check name
    if (owner->subcats) {
        int i;
        for(i = 0 ; i < owner->subcats->size ; i++ ) {
            YAMJSubCat *sc = owner->subcats->array[i];
            if (STRCMP(sc->name,name) == 0) {
                // Duplicate subcat
                if (alert_duplicate) {
                    html_error("duplicate sub category [%s_%s]",owner->name,name);
                    ret = NULL;
                } else {
                    ret = sc;
                }
                return ret;
            }
        }
    }

    ret = CALLOC(sizeof(YAMJSubCat),1);
    ret->name = STRDUP(name);
    ret->owner_cat = owner;

    ret->filter_expr_url = STRDUP(filter_url);

    if (EMPTY_STR(ret->filter_expr_url)) {

        if (require_filter) {

            html_error("missing query value for subcat [%s_%s]",owner->name,name);
            free_yamj_subcatetory(ret);
            ret = NULL;
        }

    } else if ((ret->filter_expr = parse_full_url_expression(ret->filter_expr_url)) == NULL) {

        html_error("unable to parse query value for [%s_%s]",owner->name,name);
        free_yamj_subcatetory(ret);
        ret = NULL;
    }

    if (ret) {

        if (owner->subcats == NULL) {
            owner->subcats = array_new(free_yamj_subcatetory);
        }
        array_add(owner->subcats,ret);
    }

    return ret;
}

void add_index_to_item(DbItem *item,YAMJSubCat *subcat)
{

    if (!item->yamj_member_of) {
        item->yamj_member_of = array_new(NULL);
    }
    array_add(item->yamj_member_of,subcat);
}

#if 0
/*
* If this item is eligibe for addition to the current YAMJ file , then also find all other categories it
* belongs to.  Required for YAMJ indexes. not needed with full dynamic jukebox.
*/
int add_item_indexes(DbItem *item,Array *categories,YAMJSubCat *subcat)
{
    int i;
    for(i = 0 ; i < categories->size ; i++ ) {

        int j;

        YAMJCat *cat = categories->array[i];
        Exp *e = cat->auto_subcat_expr;
        if (e) {
            
            
        } else {
            // static subcategory - check all subcategories to build 

            for(j = 0 ; j < cat->subcats->size ; j++ ) {
                YAMJSubCat *sc = cat->subcats->array[j];
                if (sc != subcat && sc->filter_expr) { 
                    Exp *e = sc->filter_expr;
                    if (evaluate_num(e,item)) {
                        add_index_to_item(item,sc);
                    }
                }
            }
        }
    }
}
#endif

/*
 * For dynamic subcats -
 * compare the evaluated expression against the expected target(selected_subcat) name
 *
 * IN target_name - if present then the expression is checked against this value
 * return 1=match
 * 0 = no match
 * -1 = error
 *
 * Two sideeffects:
 * 1. Dynamic subcats are created for each unique expression result seen - eg to populate Title_YYY_1, Genre_XXX_1
 * 2. The item->yamj_member_of array is updated with the new dynamic subcats.
 */
int create_dynamic_cat_expression(YAMJCat *cat,DbItem *item,Exp *e,char *selected_subcat_name)
{
    char *val;
    int keeprow=-1;
    // Create a new subcat if none exists.
    // Just use a simple loop - no hashes as numbers should be small
    if (e->val.type == VAL_TYPE_STR) {

        val = e->val.str_val;

        add_index_to_item(item,new_subcat(cat,val,NULL,0,0));

        if (selected_subcat_name) {
            keeprow = (STRCMP(selected_subcat_name,val) == 0);
        }

    } else if (e->val.type == VAL_TYPE_NUM) {

        // TODO loss of precicsion here - may affect rating filters.
        char num[20];
        sprintf(num,"%f",e->val.num_val);
        char *p = strrchr(num,'\0');
        while (*(--p) == '0') {
            ;
        }
        *++p='\0';
        add_index_to_item(item,new_subcat(cat,num,NULL,0,0));
        if (selected_subcat_name) {
            keeprow = (strcmp(selected_subcat_name,num) == 0);
        }

    } else if (e->val.type == VAL_TYPE_LIST) {
        int j;
        keeprow=0;
        for(j = 0 ; j < e->val.list_val->size ; j++ ) {
            val = e->val.list_val->array[j];
            add_index_to_item(item,new_subcat(cat,val,NULL,0,0));

            if (selected_subcat_name) {
                if (STRCMP(selected_subcat_name,val) == 0) {
                    keeprow = 1;
                }
            }
        }
    } else {
        HTML_LOG(0,"could not compute for item id %d",item->id);
        exp_dump(e,3,1);
    }
    return keeprow;

}

#define STATIC_CAT(c) ((c)->auto_subcat_expr == NULL)
#define DYNAMIC_CAT(c) ((c)->auto_subcat_expr != NULL)
#define STATIC_SUBCAT(s) STATIC_CAT((s)->owner_cat)
#define DYNAMIC_SUBCAT(s) DYNAMIC_CAT((s)->owner_cat)
/*
 * if subcat parent is a dynamic category then check evaluated value against subcat name
 *      eg Title_A_1.xml check computed 1st letter of title against current subcat name 'A'
 *
 * returns true if this item matches the current selected subcat
 */
int add_dynamic_subcategories(DbItem *item,Array *categories,char *selected_subcat_name)
{
    int keeprow = 0;
    int i;
    for(i = 0 ; i < categories->size ; i++ ) {

        YAMJCat *cat = categories->array[i];

        Exp *e = cat->auto_subcat_expr;
        if (e) {

            // If the current category is a dynamic category and it contains our current subcategory and 
            // we have not yet selected this row then check to see if row is eligible for selection.
            
            if (evaluate(e,item) == 0) {

                if (create_dynamic_cat_expression(cat,item,e,selected_subcat_name) == 1) {
                    // match
                    keeprow = 1;
                }
            }
        }
    }
    return keeprow;
}


/*
 * For each row do two things.
 * 1. Evaluate any dynamic categories - eg First Letter of Title , Genre list etc.
 * 3. if subcat parent is not a dynamic category then evaluate the subcat - keeprow if true
 *      eg _Y~f~~e~2010 for movies in 2010
 */
int yamj_check_item(DbItem *item,Array *categories,YAMJSubCat *selected_subcat)
{
    int keeprow = 0;

    //HTML_LOG(0,"TRACE1 [%s] [%s]",item->title,item->genre);
    /*
     * Update all dynamic subcats for this item.
     * For YAMJ dynamic subcats must be populated because all XML files contain subcat menus. eg Title_B_1.xml
     *
     * As we had to evalute the expression to build subcat menus, als use the expression to 
     * a) determine whether to keep this item (for selected subcat).
     * b) Populate item->yamj_member_of populated for dynamic subcats only for the /movies/movie/index tags.
     */
    keeprow = add_dynamic_subcategories(item,categories,selected_subcat?selected_subcat->name:NULL);

    /*
     * If no dynamic subcat matches (which have to be built anyway for the Category selections)
     * then check the explicitly selected * static subcat.
     */
    if (!keeprow) {
        if (selected_subcat == NULL) {
            // No filter - eg main home view.
            keeprow = 1;

        } else if (STATIC_SUBCAT(selected_subcat)) {

            // Now if current subcat is NOT part of a dynamic category then evaluate its filter and check
            // value is non-zero.
            if (selected_subcat->filter_expr) {
                Exp *e = selected_subcat->filter_expr;
                keeprow = evaluate_num(e,item) != 0;

                //HTML_LOG(0," title [%s] cat %c",item->title,item->category);
                //exp_dump(e,10,1);
                if (keeprow) {
                    add_index_to_item(item,selected_subcat);
                }
            }
        }
    }

    //TRACE1;
    return keeprow;

    /* Now the item->yamj_member_of is partially populated with
     * 1) all matching dynamic subcats.
     * 2. the current user selected static subcat if any
     * This leaves all of the other static subcats. These only need to be populated 
     * if the item is going in the actual xml
     * see add_static_indices_to_item()
     */
}

/*
 * This is called to populate the final indices for the given item
 * Due to layout of YAMJ XML files:
 * 1. We have already computed all of the dynamic sub categories in order to build index for skins - so if item is a member of these
 * this is already set in item->yamj_member_of
 * 2. If current user subcat is static we have checked this to see if item is going in current XML - again this will be in
 * item->yamj_member_of
 * All that remains are other static subcats.
 */
void add_static_indices_to_item(DbItem *item,YAMJSubCat *selected_subcat,Array *categories)
{
    int i;
    for(i = 0 ; i < categories->size ; i++ ) {

        YAMJCat *cat = categories->array[i];
        if (STATIC_CAT(cat)) {

            int j;
            for(j = 0 ; j < cat->subcats->size ; j++ ) {

                YAMJSubCat *sc = cat->subcats->array[j];
                
                if (sc != selected_subcat) { // already processed selected subcat at this point

                    if(sc->filter_expr) {

                        if (evaluate_num(sc->filter_expr,item)) {

                            //  This is ONLY called for items that are being written to the current YAMJ XML
                            //  so the totals are not meaningful here.
                            add_index_to_item(item,sc);
                        }
                    }
                }
            }
        }
    }
}

/*
 * contents are overwritten must not be freed
 */
char *xmlstr_static(char *text)
{
    static char *out=NULL;
    static int free_last = 0;
    if (out && free_last) {
        FREE(out);
        free_last=0;
    }
    out = text;
    if (strchr(out,'<')) out = replace_str(text,"<","&lt;");

    if (strchr(out,'>')) {
       char *tmp = replace_str(out,">","&gt;");
       if (out != text) FREE(out);
       out = tmp;
    }

    free_last =  (out != text);

    return out;
}

void video_field_long(char *tag,long value,char *attr,char *attrval)
{

    if (value || attrval ) {
        printf("\t<%s",tag);
        if (attrval) {
            printf(" %s=\"%s\"",attr,attrval);
        }
        printf(">%ld</%s>\n",value,tag);
    }
}

void video_field(char *tag,char *value,int url_encode,char *attr,char *attrval)
{

    char *encoded=NULL;
    int free_it=0;

    if (value || attrval ) {
        printf("\t<%s",tag);
        if (attrval) {
            printf(" %s=\"%s\"",attr,attrval);
        }
        printf(">");
        if (url_encode) {
            encoded=url_encode_static(value,&free_it);
        } else {
            encoded = value;
            free_it = 0;
        }
        printf("%s</%s>\n",xmlstr_static(encoded),tag);
        if (free_it) {
            FREE(encoded);
        }
    }
}


int yamj_video_xml(char *request,DbItem *item,int details,DbItem *all_items,int pos,int total)
{
    int i;
    int ret = 1;
    if (item == NULL) {
        HTML_LOG(0,"TODO html log get dbitem using request details [%s]",request);
    }
    printf("<movie>\n");
    char *id;
    
    //printf("\t<id moviedb=\"ovs\">%ld</id>\n",item->id);

    id = get_id_from_idlist(item->url,"imdb",1);
    if (id) {
        printf("\t<id moviedb=\"imdb\">%s</id>\n",strchr(id,':')+1);
        FREE(id);
    }

    if (0 && id) {
        printf("\t<id moviedb=\"tmdb\">%s</id>\n",strchr(id,':')+1);
        FREE(id);
    }

    if (0 && id) {
        printf("\t<id moviedb=\"thetvdb\">%s</id>\n",strchr(id,':')+1);
        FREE(id);
    }
    printf("\t<mjbVersion>2.6-SNAPSHOT</mjbVersion>\n");
    printf("\t<mjbRevision>1234</mjbRevision>\n");

    printf("\t<baseFilenameBase>%ld</baseFilenameBase>\n",item->id);
    printf("\t<baseFilename>%ld</baseFilename>\n",item->id);

    video_field("title",NVL(item->title),0,NULL,NULL);


    if (item->rating != 0.0) {
        printf("\t<rating>%d</rating>\n",(int)(item->rating *100));
    }

    printf("\t<watched>%s</watched>\n",(item->watched?"true":"false"));

    
    char *poster = internal_image_path_static(item,POSTER_IMAGE,1);
    if (*poster ) {
        printf("\t<posterFile>%s%s</posterFile>\n",YAMJ_POSTER_PREFIX,poster);
        printf("\t<detailPosterFile>%s%s</detailPosterFile>\n",YAMJ_POSTER_PREFIX,poster);
        printf("\t<thumbnail>%s%s</thumbnail>\n",YAMJ_THUMB_PREFIX,poster);
    }

    char *fanart = internal_image_path_static(item,FANART_IMAGE,1);
    if (*fanart ) {
        printf("\t<fanartFile>%s%s</fanartFile>\n",YAMJ_FANART_PREFIX,fanart);
    }

    video_field("originalTitle",NVL(item->orig_title),0,NULL,NULL);

    printf("\t<year>%d</year>\n",item->year);

    video_field("certification",item->certificate,0,NULL,NULL);
    printf("\t<season>%d</season>\n",(item->category == 'T' ? item->season : -1 ));

    video_field("language","",0,NULL,NULL);
    video_field("subtitles","",0,NULL,NULL);
    video_field("trailerExchange","",0,NULL,NULL);
    video_field("trailerLastScan","",0,NULL,NULL);
    video_field("container","",0,NULL,NULL);
    video_field("videoCodec","UNKNOWN",0,NULL,NULL);
    video_field("audioCodec","UNKNOWN",0,NULL,NULL);
    video_field("audioChannels","",0,NULL,NULL);
    video_field("resolution","UNKNOWN",0,NULL,NULL);
    video_field("videoSource",item->videosource,0,NULL,NULL);
    video_field("videoOutput","UNKNOWN",0,NULL,NULL);
    video_field("aspect","UNKNOWN",0,NULL,NULL);
    video_field("fps","60",0,NULL,NULL);

    char *date_format="%y-%m-%d";
#define DATE_BUF_SIZ 40
    char date[DATE_BUF_SIZ];
    if (item->filetime) {
        strftime(date,DATE_BUF_SIZ,date_format,internal_time2tm(item->filetime,NULL));
        video_field("fileDate",date,0,NULL,NULL);
    }
    if (item->sizemb) {
        printf("\t<fileSize>%d MBytes</fileSize>\n",item->sizemb);
    }

    //---------------------------
    //
    if (total) printf("\t<first>%ld</first>\n",all_items[0].id);

    if (pos>0) {
        printf("\t<previous>%ld</previous>\n",all_items[pos-1].id);
    } else {
        printf("\t<previous>UNKNOWN</previous>\n");
    }

    if (pos<total-1) {
        printf("\t<next>%ld</next>\n",all_items[pos+1].id);
    } else {
        printf("\t<next>UNKNOWN</next>\n");
    }
    if (total) printf("\t<last>%ld</last>\n",all_items[total-1].id);

    //---------------------------
    
    Array *genres = splitstr(item->expanded_genre,"|");
    printf("\t<genres count=\"%d\">\n",genres->size);
    for(i = 0 ; i < genres->size ; i++ ) {
        char *g = genres->array[i];
        printf("\t\t<genre index=\"Genres_%s_1\">%s</genre>\n",g,g);
    }
    printf("\t</genres>\n");
    array_free(genres);

    //---------------------------

    if (item->yamj_member_of) {
        int i;
        printf("\t<indexes>\n");
        for(i= 0 ; i<item->yamj_member_of->size ; i++ ) {
            int free_it;
            YAMJSubCat *sc = item->yamj_member_of->array[i];

            char *name=sc->name;
            char *ownername=sc->owner_cat->name;
            char *encname=url_encode_static(name,&free_it);

            printf("\t\t<index encoded=\"%s\" originalName=\"%s\" type=\"%s\">%s</index>\n",
                encname,ownername,ownername,encname);

            if(free_it) FREE(encname);

        }
        printf("\t</indexes>\n");
    }

    //----------------------------

    char *plot = get_plot(item,PLOT_MAIN);
    printf("\t<plot>%s</plot>\n",xmlstr_static(plot));
    FREE(plot);
        

    printf("\t<episode>%s</episode>\n",xmlstr_static(NVL(item->episode)));

    printf("</movie>\n");
    return ret;
}

/*
 * request = input argument
 * subcat = Sub category corresponding to input
 * cat = any category for output. If it contains the current subcat then extr page info is output.
 */
int yamj_category_xml(char *request,YAMJSubCat *subcat,YAMJCat *cat,DbItemSet **item_sets)
{
    int ret = 1;
    int i;


    if (subcat && subcat->owner_cat == cat) {
    HTML_LOG(0,"subcat %s_%s total = %d movies , %d series , %d episodes , %d other",
            cat->name,subcat->name,
            item_sets[0]->movie_total,
            item_sets[0]->series_total,
            item_sets[0]->episode_total,
            item_sets[0]->other_media_total
            );
    }
    HTML_LOG(0,"cat [%s]",xmlstr_static(cat->name));
    printf("<category count=\"%d\" name=\"%s\">\n",cat->subcats->size,cat->name);
    for(i = 0 ; i < cat->subcats->size ; i++ ) {
        YAMJSubCat *s = cat->subcats->array[i];
        printf("\t<index name=\"%s\"",s->name);
        if (s == subcat) {

            int last = 1+(s->item_total/s->owner_cat->page_size);
            int first = 1;
            int next = s->page + 1;
            if (next > last) next = last;

            int prev = s->page - 1;
            if (prev < first ) prev = first;

            printf("\n\t\tcurrent=\"true\"\n");
            printf("\t\tcurrentIndex=\"%d\"\n",subcat->page);

            printf("\t\tfirst=\"%s_%s_%d\"\n",s->owner_cat->name,s->name,first);
            printf("\t\tlast=\"%s_%s_%d\"\n",s->owner_cat->name,s->name,last);
            printf("\t\tnext=\"%s_%s_%d\"\n",s->owner_cat->name,s->name,next);
            printf("\t\tprevious=\"%s_%s_%d\"\n",s->owner_cat->name,s->name,prev);
            printf("\t\tlastIndex=\"%d\"",last);
        }

        // url encode the cat_subcat_1 
        char *name,*name_enc;
        int free_it;
        ovs_asprintf(&name,"%s_%s_1",s->owner_cat->name,s->name);
        name_enc = url_encode_static(name,&free_it);
        printf(">%s</index>\n",name_enc);
        if (free_it) FREE(name_enc);
        FREE(name);

    }
    printf("</category>\n");
    return ret;
}


/*
 * config file format:
 * ovs_yamj_cat1_sub1_name="1950-59"
 * ovs_yamj_cat1_sub1_query="_Y~f~~ge~1950~a~_Y~f~~le~1959"
 */
YAMJSubCat *yamj_subcat_config(YAMJCat *owner,int num,int sub)
{
    YAMJSubCat *ret = NULL;

    char *key=NULL;
    char *name;

    ovs_asprintf(&key,CONFIG_PREFIX "%d_sub%d_name",num,sub);
    name = oversight_val(key);
    if (!EMPTY_STR(name)) {

        
        FREE(key);
        ovs_asprintf(&key,CONFIG_PREFIX "%d_sub%d_query",num,sub);

        char *query = oversight_val(key);

        HTML_LOG(0,"query = [%s]",query);

        ret = new_subcat(owner,name,query,1,1);
    }

    FREE(key);
    if (ret) {
        HTML_LOG(0,"read subcat[%d,%d] name=[%s] auto_subcat_expr_url=[%s]",num,sub,ret->name,ret->filter_expr_url);
    }
    return ret;
}

/**
 * A ovs_yamj_cat has one of two following config definition:
 *
 * Explicitly named subcategories each with their own query:
 *
 * ovs_yamj_cat1_name="Year"
 * ovs_yamj_cat1_sub1_name="1950-59"
 * ovs_yamj_cat1_sub1_query="_Y~f~~ge~1950~a~_Y~f~~le~1959"
 * ovs_yamj_cat1_sub2_name="1960-69"
 * ovs_yamj_cat1_sub2_query="_Y~f~~ge~1960~a~_Y~f~~le~1969"
 *
 * or subcategories are implicitly generated from an expression run against all entries in the database.
 *
 * ovs_yamj_cat2_name="Title"
 * ovs_yamj_cat2_expr="_T~f~~l~1"
 *
 * or
 *
 * ovs_yamj_cat3_name="Certification"
 * ovs_yamj_cat3_expr="_R~f~"
 *
 * The query syntax is borrowed from the existing URL query syntax. See parse_url_expression() [exp.c] and filter.c
 * TODO: Some additions are required.
 * String~l~number = first [number] characters of String
 * ~sp~ = split a string into a list. This will be eventually used to process Genres, Actors etc.
 *
 *
 */
YAMJCat *yamj_cat_config(int num)
{
    YAMJCat *ret = NULL;

    char *key;
    char *name;

    YAMJSubCat *subcat;

    ovs_asprintf(&key,CONFIG_PREFIX "%d_name",num);
    name = oversight_val(key);
    if (!EMPTY_STR(name)) {

        ret = CALLOC(1,sizeof(YAMJCat));

        ret->name = STRDUP(name);
        
        FREE(key);
        ovs_asprintf(&key,CONFIG_PREFIX "%d_expr",num);

        ret->auto_subcat_expr_url = STRDUP(oversight_val(key));

        int j = 0;
        while((subcat = yamj_subcat_config(ret,num,++j)) != NULL) {
            /** EMPTY LOOP **/;
        }

        if (EMPTY_STR(ret->auto_subcat_expr_url)) {
            if (j == 1) {
                html_error("missing query  or expr value for ovs_yamj_cat[%d]",num);
                free_yamj_catetory(ret);
                ret = NULL;
            }
        } else if ((ret->auto_subcat_expr = parse_full_url_expression(ret->auto_subcat_expr_url)) == NULL) {
            html_error("missing query  or expr value for ovs_yamj_cat[%d]",num);
        }
    }

    FREE(key);
    if (ret) {
        HTML_LOG(0,"read cat[%d] name=[%s] expr=[%s]",num,ret->name,ret->auto_subcat_expr_url);
    }
    return ret;
}

int yamj_build_categories(char *cat_name,Array *categories) 
{
    int ret = 1;
    HTML_LOG(0,"TODO yamj_build_categories");
    int i = 0;

    int page_size = 10;
    char *p = oversight_val("ovs_yamj_page_size");
    if (!EMPTY_STR(p)) {
        page_size = atoi(p);
    }
    HTML_LOG(0,"page size = %d",page_size);

    YAMJCat *yc;
    while ((yc = yamj_cat_config(++i)) != NULL) {
        yc->page_size = page_size;
        array_add(categories,yc);
    }



    return ret;
}

void dump_cat(char *label,YAMJCat *cat) 
{
    int i;
    if (cat->subcats) {
        for(i = 0 ; i < cat->subcats->size ; i++ ) {
            HTML_LOG(0,"catdump %s %s %s",label,cat->name,((YAMJSubCat *)(cat->subcats->array[i]))->name);
        }
    }
}

int cat_cmp(const void *a,const void *b)
{
    return STRCMP((*(YAMJCat **)(a))->name,(*(YAMJCat **)(b))->name);
}
int subcat_cmp(const void *a,const void *b)
{
    return STRCMP((*(YAMJSubCat **)(a))->name,(*(YAMJSubCat **)(b))->name);
}
void sort_categories(Array *categories)
{
    int i;
    array_sort(categories,cat_cmp);

    for(i = 0 ; i < categories->size ; i++ ) {
        YAMJCat *cat = categories->array[i];
        array_sort(cat->subcats,subcat_cmp);
    }
}



int yamj_categories_xml(char *request,YAMJSubCat *selected_subcat,Array *categories,DbItemSet **itemSet)
{
    int ret = 1;
    int i;


    printf("<library count=\"%d\">\n",categories->size);

/*
 * if (!selected_subcat) {
        html_error("unknown request [%s]",request);
        printf("<error>see html comments</error>\n");
    }
    */

    for(i = 0 ; i < categories->size ; i++ ) {
        YAMJCat *cat = categories->array[i];
        yamj_category_xml(request,selected_subcat,cat,itemSet);
    }



    if (selected_subcat && itemSet) {

        if (itemSet[1]) assert(0); //TODO crossview not coded
        int num = itemSet[0]->size;
        // itemSet = array of rowsets. One item for each database source. 
        printf("<movies count=\"%d\">\n",num);


        int page_size = selected_subcat->owner_cat->page_size;
        int start = (selected_subcat->page-1) * page_size;
        int end = start + page_size;

        if ( start >= num ) start = num;
        if ( end >= num ) end = num;

        HTML_LOG(0,"page %d page size = %d start = %d end = %d ",selected_subcat->page,page_size,start,end);


        for (i = start ; i < end ; i++ ) {
            DbItem *item = itemSet[0]->rows+i;

            // Finish populating item->yamj_member_of with all categories this member belongs to
            add_static_indices_to_item(item,selected_subcat,categories);

            yamj_video_xml(request,item,0,itemSet[0]->rows,i,num);
        }
        printf("</movies>\n");
    }
    printf("</library>\n");

    array_free(categories);
    return ret;

}

/**
 * Some subcats are created on the fly eg Title_Letter_Page.xml
 * Letter is derived from database contents, as first UTF-8 character of item titles.
 * Whilst computing these the subcat items will get populated.
 */
int evaluate_dynamic_subcat_names(YAMJCat *cat)
{
    int ret = 1;

    assert(cat);
    if (cat->auto_subcat_expr_url && !cat->evaluated) {
        HTML_LOG(0,"TODO evaluate expression here and populate subcats");
        cat->evaluated = 1;
    } else {
        HTML_LOG(0,"already have subcats");
    }

    return ret;
}

/*
 * check name = Category_SubCat_Page.xml
 */
YAMJSubCat *find_subcat(char *request,Array *categories)
{
    int i,j;
    YAMJSubCat *subcat=NULL;
    char *pattern = "([^_]+)_([^_].*)_([0-9]+).xml";
    int page;

    assert(request);
    assert(categories);

    Array *request_parts = regextract(request,pattern,0);

    if (!request_parts || request_parts->size != 4) {
        html_error("invalid request [%s] expect pattern [%s]",request,pattern);
        array_dump(0,"regex",request_parts);
    } else {

        char *cat_name = request_parts->array[1];
        char *subcat_name = request_parts->array[2];
        page = atoi(request_parts->array[3]);


        HTML_LOG(0,"findCat - %s - %s - %d",cat_name,subcat_name,page);
        // See if the subcat exists.
        //
        YAMJCat *cat = NULL;

        for(i = 0 ; !cat && i < categories->size ; i++ ) {
            YAMJCat *cat1 = categories->array[i];
            if (strcmp(cat_name,cat1->name) == 0 ) {

                HTML_LOG(0,"found cat [%s]",cat_name);
                cat = cat1;

                Array *subcats = cat->subcats;
                if (subcats) {
                    for(j = 0 ; !subcat && j < subcats->size ; j++ ) {
                        YAMJSubCat *subcat1 = subcats->array[j];
                        if (strcmp(subcat_name,subcat1->name) == 0) {
                            subcat = subcat1;
                            HTML_LOG(0,"found subcat [%s]",subcat_name);
                        }
                    }
                }
            }
        }

        // If No subcat exists then create one using a combination of the owner_cat auto_subcat_expr_url and the
        // subcat name.
        // Eg
        //    cat->auto_subcat_expr_url = _T~f~~l~1 (1st character of title field)
        //    subcat name = B
        //    Create subcat with filter 'B'~e~_T~f~~l~1 ( 'B' = 1st character of title field )
        //
        if (!cat) {
            html_error("request [%s] : Category %s not found in configuration",request,cat_name);
        } else if (!subcat) {
            if (EMPTY_STR(cat->auto_subcat_expr_url)) {
                html_error("request [%s] : Subcategory %s not found in configuration",request,subcat_name);
            } else {
                char *query;
                ovs_asprintf(&query,"'%s'~e~%s",subcat_name,cat->auto_subcat_expr_url);
                HTML_LOG(0,"creating auto subcategory %s_%s using query %s",cat_name,subcat_name,query);
                subcat = new_subcat(cat,subcat_name,query,0,1);
                FREE(query);
            }
        }
        if (subcat) {
            subcat->page = page;
            HTML_LOG(0,"setting page %d",page);
        }
    }

    array_free(request_parts);
    return subcat;
}



int yamj_xml(char *request)
{

    int ret = 1;


        FILE *fp = fopen("/share/Apps/oversight/logs/request.log","a");
        fprintf(fp,"[%s]\n",request);
        fclose(fp);
        // request = Cat_SubCat_page.xml
        //

        if (0 && util_strreg(request,"^[0-9]+.xml$",0)) {

            // Detail files not used by eversion so we wont dwell on these.
            // write movie XML
            xml_headers();
            config_read_dimensions(0);
            HTML_LOG(0,"processing [%s]",xmlstr_static(request));
            load_configs();
            printf("<details>\n");
            ret = yamj_video_xml(request,NULL,1,NULL,0,1);
            printf("</details>\n");

        } else if ( util_strreg(request,YAMJ_THUMB_PREFIX "[^.]*\\.jpg$",0)) {

            char *file;
            ovs_asprintf(&file,"%s/db/global/_J/ovs_%s.thumb",appDir(),request+strlen(YAMJ_THUMB_PREFIX));
            //now swap in place .jpg.thumb with .thumb.jpg
            char *p = strstr(file,".jpg.thumb");
            if (p) strcpy(p,".thumb.jpg");
            // Send image
            cat(CONTENT_TYPE"image/jpeg",file);
            FREE(file);

        } else if ( util_strreg(request,YAMJ_POSTER_PREFIX "[^.]*\\.jpg$",0)) {

            char *file;
            ovs_asprintf(&file,"%s/db/global/_J/ovs_%s",appDir(),request+strlen(YAMJ_POSTER_PREFIX));
            // Send image
            cat(CONTENT_TYPE"image/jpeg",file);
            FREE(file);

        } else if ( util_strreg(request,YAMJ_FANART_PREFIX "[^.]*\\.jpg$",0)) {

            char *file;
            ovs_asprintf(&file,"%s/db/global/_fa/ovs_%s",appDir(),request+strlen(YAMJ_FANART_PREFIX));
            // Send image
            cat(CONTENT_TYPE"image/jpeg",file);
            FREE(file);

        } else if (STRCMP(request,CATEGORY_INDEX) == 0 || util_strreg(request,"[^_]+_[^_]+_[0-9]+.xml$",0)) {

            xml_headers();
            config_read_dimensions(0);
            HTML_LOG(0,"processing [%s]",xmlstr_static(request));
            load_configs();

            Array *categories = array_new(free_yamj_catetory);

            yamj_build_categories(request,categories);

            YAMJSubCat *selected_subcat = NULL;
            
            if (STRCMP(request,CATEGORY_INDEX) != 0 ) {
                selected_subcat = find_subcat(request,categories);
            }

            DbItemSet **itemSet = db_crossview_scan_titles(0,NULL,categories,selected_subcat);

            sort_categories(categories);

            yamj_categories_xml(request,selected_subcat,categories,itemSet);

        } else {
            HTML_LOG(0,"error invalid yamj request [%s] %d",xmlstr_static(request),STRCMP(request,CATEGORY_INDEX));
        }

    return ret;
}

// vi:sw=4:et:ts=4
