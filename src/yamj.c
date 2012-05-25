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
#define YAMJ_BOXSET_PREFIX "boxset_"
#define YAMJ_POSTER_PREFIX "poster_"
#define YAMJ_BANNER_PREFIX "banner_"
#define YAMJ_FANART_PREFIX "fanart_"
#define YAMJ_QUERY_NAME "query"
#define YAMJ_QUERY_PREFIX YAMJ_QUERY_NAME "_"
#define BOOL(x) ((x)?"true":"false")

#define CATEGORY_REGEX "([^_]+)_([^_].*)_([0-9]+).xml"

static int LOG_LVL=1;
// Prototypes
void add_static_indices_to_item(DbItem *item,YAMJSubCat *selected_subcat,Array *categories);
void yamj_files(DbItem *item);
int yamj_file(DbItem *item,int part_no,int show_source);
void yamj_file_part(DbItem *item,int part_no,char *part_name,int show_source);
void load_dynamic_cat(YAMJCat *cat,time_t index_time);
void save_dynamic_categories(Array *categories);
void save_dynamic_cat(YAMJCat *cat);
void yamj_people(DbItem *item,char *tag,char *tag2,DbGroupIMDB *group);
int add_dynamic_subcategories(DbItem *item,YAMJCat *cat,YAMJSubCat *selected_subcat);

FILE *xmlout=NULL;
/*
 * The plan is as follows:
 *
 * All YAML Xml category files contain information on all other categories. This is so that skins have 
 * b
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

// If true remove a lot of XML that eversion doesnt need?
static int lean_xml=0;

void xml_headers(FILE *fp)
{
    fprintf(fp,"%s%s\n\n",CONTENT_TYPE,"application/xml");
    fprintf(fp,"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n");
    fflush(fp);
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


/*
 * Crate a new subcat eg the A of Title_A_1.xml - the category is 'Title' the subcat is Title_A
 * In this cast the filter URL is _T~f~~l~~1~~e~'A'   ie Title Field Left$ 1 = 'A'
 * require_filter means a filter_url must be provided. This is  to check integrity of config file.
 */
YAMJSubCat *new_subcat(YAMJCat *owner,char *name,char *filter_url,int require_filter,int alert_duplicate)
{

    assert(owner);
    YAMJSubCat *ret = NULL;

    // check name
    if (owner && owner->subcats) {
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

            html_error("missing query value for subcat [%s_%s]",(owner?owner->name:"?"),name);
            free_yamj_subcatetory(ret);
            ret = NULL;
        }

    } else if ((ret->filter_expr = parse_full_url_expression(ret->filter_expr_url,TOKEN_URL)) == NULL) {

        html_error("unable to parse query value for [%s_%s]",(owner?owner->name:"?"),name);
        free_yamj_subcatetory(ret);
        ret = NULL;
    }

    if (ret && owner) {

        if (owner->subcats == NULL) {
            owner->subcats = array_new(free_yamj_subcatetory);
        }
        array_add(owner->subcats,ret);
    }

    return ret;
}

void add_index_to_item(DbItem *item,YAMJSubCat *subcat)
{
    if (!lean_xml) {

        if (!item->yamj_member_of) {
            item->yamj_member_of = array_new(NULL);
        }
        array_add(item->yamj_member_of,subcat);
    }
    subcat->item_total++;
}

char *exp_as_string_static(Exp *e)
{
    char *val=NULL;
    if (e->val.type == VAL_TYPE_STR) {

        val = e->val.str_val;

    } else if (e->val.type == VAL_TYPE_NUM) {

        // TODO loss of precicsion here - may affect rating filters.
        char num[20];
        sprintf(num,"%f",e->val.num_val);
        char *p = strrchr(num,'\0');
        while (*(--p) == '0') {
            ;
        }
        *++p='\0';
        val = num;
    }
    return val;
}

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
int add_all_dynamic_subcategories(DbItem *item,Array *categories,YAMJSubCat *selected_subcat)
{
    int keeprow = 0;
    int i;
    for(i = 0 ; i < categories->size ; i++ ) {

        YAMJCat *cat = categories->array[i];
        if (add_dynamic_subcategories(item,cat,selected_subcat)) {
            keeprow = 1;
        }
    }
    return keeprow;
}

int add_dynamic_subcategories(DbItem *item,YAMJCat *cat,YAMJSubCat *selected_subcat)
{
    int keeprow = 0;

    Exp *e = cat->auto_subcat_expr;
    if (e && !(cat->evaluated)) {

        // If the current category is a dynamic category and it contains our current subcategory and 
        // we have not yet selected this row then check to see if row is eligible for selection.
        
        if (evaluate(e,item) == 0) {

            if (selected_subcat == NULL || selected_subcat->owner_cat != cat) {
                // evaluate dynamic subcats for main menu
                create_dynamic_cat_expression(cat,item,e,NULL);
            } else {
                // Check this item against the selected subcat at the same time

                if (create_dynamic_cat_expression(cat,item,e,selected_subcat->name) == 1) {
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
    if (selected_subcat == NULL || !lean_xml ) {
        // This is the main menu or we are in proper YAMJ mode - generate all menus to duplicate in all XMLs
        keeprow = add_all_dynamic_subcategories(item,categories,selected_subcat);
    } else {
        // This is not the main menu - so we really only want the details for the current subcat so
        // Eversion knows where it is in the index.
        keeprow = add_dynamic_subcategories(item,selected_subcat->owner_cat,selected_subcat);
    }

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
        } else if (selected_subcat->owner_cat->evaluated) {
            // If the expression was a pre-loaded auto subcat then check if the expression value matches the subcat name
            // THIS MIGHT BE OBSOLETED it is dependent on loading the subcats from a flat file but Eversion doesnt 
            // really need them in every file.
            Exp *e = selected_subcat->owner_cat->auto_subcat_expr;
            if (evaluate(e,item) == 0) {
            //HTML_LOG(0,"check preloaded [%s][%s]",item->title,selected_subcat->name);
                char *v = exp_as_string_static(e);
                if (v && strcmp(v,selected_subcat->name) == 0) {
                    keeprow = 1;
                    add_index_to_item(item,selected_subcat);
                }
            }
        }
    }

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
        if (STATIC_CAT(cat) && cat->subcats) {

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


void video_field_long(char *tag,long value,char *attr,char *attrval)
{

    if (value || attrval ) {
        fprintf(xmlout,"\t<%s",tag);
        if (attrval) {
            fprintf(xmlout," %s=\"%s\"",attr,attrval);
        }
        fprintf(xmlout,">%ld</%s>\n",value,tag);
    }
}

void video_field(char *tag,char *value,int url_encode,char *attr,char *attrval)
{

    char *encoded=NULL;
    int free_it=0;

    if (!EMPTY_STR(value) || !EMPTY_STR(attrval) ) {
        fprintf(xmlout,"\t<%s",tag);
        if (attrval) {
            fprintf(xmlout," %s=\"%s\"",attr,attrval);
        }
        fprintf(xmlout,">");
        if (url_encode) {
            encoded=url_encode_static(value,&free_it);
        } else {
            encoded = value;
            free_it = 0;
        }
        fprintf(xmlout,"%s</%s>\n",xmlstr_static(encoded,0),tag);
        if (free_it) {
            FREE(encoded);
        }
    }
}

Array *split_request(char *request)
{
    Array *request_parts = regextract(request,CATEGORY_REGEX,0);
    if (!request_parts || request_parts->size != 4) {
        html_error("invalid request [%s] expect pattern [%s]",request,CATEGORY_REGEX);
        array_dump(0,"regex",request_parts);
        if (request_parts) {
            array_free(request_parts);
            request_parts = NULL;
        }
    }
    return request_parts;
}

char *base_name(DbItem *item,ViewMode *view)
{
    char *result=NULL;
    if (view == VIEW_TV) {
//        if (!lean_xml) { // Eversion doesnt use detail files
            set_plot_keys(item);
            ovs_asprintf(&result,"%s",item->plotkey[PLOT_MAIN]);
//        }
    } else if (view == VIEW_TVBOXSET) {
        // TODO quotes
        ovs_asprintf(&result, YAMJ_QUERY_PREFIX "T~c~_C~f~~a~(_T~f~~e~'%s')_1",item->title);

    } else if (view == VIEW_MOVIEBOXSET) {
        // for now we use the first set id - this will need to change in future to support movies in multiple sets.
        // at present sets are attributes of movies, and we make one pass of the database.
        // In future as well as the item->title we must look at all of the item->sets and include the video under that letter too.
        // TODO need to compare against all sets - or supplut multple sets in some way
        char *imdb = get_item_id(item,"imdb",0);
        if (imdb) {
            if (item->sets) {
                // name is imdbid_setid
                ovs_asprintf(&result, YAMJ_QUERY_PREFIX "M~c~_C~f~~a~((_U~f~~c~'%s')~o~(_a~f~~c~'%s'))_1",imdb,item->sets);
            } else {
                // name is imdbid
                ovs_asprintf(&result, YAMJ_QUERY_PREFIX "M~c~_C~f~~a~(_U~f~~c~'%s')_1",imdb);
            }
        } if (item->sets) {
            // name is setid
            ovs_asprintf(&result, YAMJ_QUERY_PREFIX "M~c~_C~f~~a~(_a~f~~c~'%s')_1",item->sets);
        }


    } else {
        if (!lean_xml) { // Eversion doesnt use detail files
            // default name
            ovs_asprintf(&result,"%ld",item->id);
        }
    }
    return result;
}

char *yamj_image_path(DbItem *item,ImageType type,char *shrt_prefix)
{
    char *path = NULL;
    if (*oversight_val("ovs_yamj_full_image_path") == '1') {
        char *tmp = get_picture_path(1,&item,type,NULL);
        if(tmp) {
            path = file_to_url(tmp);
            FREE(tmp);
        }
    } else {
        // use shorter - name only image paths - for Eversion compatability
        path = internal_image_path_static(item,type,1);
        ovs_asprintf(&path,"%s%s",shrt_prefix,path);
    }
    return path;
}

int yamj_video_xml(char *request,DbItem *item,int details,DbItem **all_items,int pos,int total)
{
    int i;
    int ret = 1;
    int is_boxset=0;

    ViewMode *view = get_drilldown_view(item);

    if (item == NULL) {
        HTML_LOG(0,"TODO html log get dbitem using request details [%s]",request);
    }
    is_boxset = (view==VIEW_TVBOXSET||view==VIEW_MOVIEBOXSET);
    HTML_LOG(0,"movie");
    fprintf(xmlout,"<movie isExtra=\"false\" isTV=\"%s\" isSet=\"%s\">\n", BOOL(view==VIEW_TV || view==VIEW_TVBOXSET) , BOOL(is_boxset));
    char *id;
    
    //fprintf(xmlout,"\t<id moviedb=\"ovs\">%ld</id>\n",item->id);

    id = get_id_from_idlist(item->url,"imdb",1);
    if (id) {
        fprintf(xmlout,"\t<id moviedb=\"imdb\">%s</id>\n",strchr(id,':')+1);
        FREE(id);
    }

    if (0 && id) {
        fprintf(xmlout,"\t<id moviedb=\"tmdb\">%s</id>\n",strchr(id,':')+1);
        FREE(id);
    }

    if (0 && id) {
        fprintf(xmlout,"\t<id moviedb=\"thetvdb\">%s</id>\n",strchr(id,':')+1);
        FREE(id);
    }

    if (!lean_xml) {
        fprintf(xmlout,"\t<mjbVersion>Oversight-2</mjbVersion>\n");
        fprintf(xmlout,"\t<mjbRevision>%s</mjbRevision>\n",OVS_VERSION);
    }

    char *b =base_name(item,view);
    if (b) {
        fprintf(xmlout,"\t<baseFilenameBase>%s</baseFilenameBase>\n",b);
        fprintf(xmlout,"\t<baseFilename>%s</baseFilename>\n",b);
        FREE(b);
    }

    //TODO get setname here
    fprintf(xmlout,"\t<title>%s</title>\n",xmlstr_static(item->title,0));

    char *sort = item->title;
    if (STARTS_WITH_THE(sort)) {
        sort +=4;
    }
    fprintf(xmlout,"\t<titleSort>%s</titleSort>\n",xmlstr_static(NVL(sort),0));

    video_field("originalTitle",NVL(item->orig_title),0,NULL,NULL);

    fprintf(xmlout,"\t<year>%d</year>\n",item->year);

    if (item->rating != 0.0) {
        fprintf(xmlout,"\t<rating>%d</rating>\n",(int)(item->rating *10));
    }

    int w = is_watched(item);
    if (!lean_xml || w) {
        fprintf(xmlout,"\t<watched>%s</watched>\n",BOOL(w));
    }

    fprintf(xmlout,"\t<top250>%d</top250>\n",item->top250);

    fprintf(xmlout,"\t<details>NO.html</details>\n");
    
    //fprintf(xmlout,"\t<posterURL>UNKNOWN</posterURL>\n");

    char *poster = yamj_image_path(item,POSTER_IMAGE,YAMJ_POSTER_PREFIX);
    if(!EMPTY_STR(poster)) fprintf(xmlout,"\t<posterFile>%s</posterFile>\n",poster);
    if(!EMPTY_STR(poster)) fprintf(xmlout,"\t<detailPosterFile>%s</detailPosterFile>\n",poster);
    if (poster) FREE(poster);

    char *thumb = yamj_image_path(item,POSTER_IMAGE,(is_boxset?YAMJ_BOXSET_PREFIX:YAMJ_THUMB_PREFIX));
    if(!EMPTY_STR(thumb)) fprintf(xmlout,"\t<thumbnail>%s</thumbnail>\n",thumb);
    if (thumb) FREE(thumb);

    char *banner = yamj_image_path(item,POSTER_IMAGE,YAMJ_BANNER_PREFIX);
    if(!EMPTY_STR(banner)) fprintf(xmlout,"\t<bannerFile>%s</bannerFile>\n",banner);
    if (banner) FREE(banner);

    char *fanart = yamj_image_path(item,FANART_IMAGE,YAMJ_FANART_PREFIX);
    if(!EMPTY_STR(fanart)) fprintf(xmlout,"\t<fanartFile>%s</fanartFile>\n",fanart);
    if (fanart) FREE(fanart);


    if (!lean_xml) {
        fprintf(xmlout,"\t<bannerURL>UNKNOWN</bannerURL>\n");
        fprintf(xmlout,"\t<fanartURL>UNKNOWN</fanartURL>\n");
    }

    char *plot = get_plot(item,PLOT_MAIN);
    char *p = xmlstr_static(plot,0);
    if (p && p[2] == ':' && util_strreg(p,"^[a-z][a-z]:",0)) {
        p += 3;
    }
    fprintf(xmlout,"\t<plot>%s</plot>\n",p);
    FREE(plot);

    if (item->runtime) {
        int min = item->runtime;
        fprintf(xmlout,"\t<runtime>");
        if (min<=60) {
            fprintf(xmlout,"%d min",min);
        } else if (min%60) {
            fprintf(xmlout,"%dh %d min",min/60,min%60);
        } else {
            fprintf(xmlout,"%dh",min/60);
        }
        fprintf(xmlout,"</runtime>\n");
    }

    video_field("certification",item->certificate,0,NULL,NULL);
    fprintf(xmlout,"\t<season>%d</season>\n",(item->category == 'T' ? item->season : -1 ));

    video_field("language","UNKNOWN",0,NULL,NULL);
    video_field("subtitles","",0,NULL,NULL);
    video_field("trailerExchange","",0,NULL,NULL);
    video_field("trailerLastScan","",0,NULL,NULL);
    video_field("container","",0,NULL,NULL);
    video_field("videoCodec","UNKNOWN",0,NULL,NULL);
    video_field("audioCodec","UNKNOWN",0,NULL,NULL);
    video_field("audioChannels","",0,NULL,NULL);

    // Oversight just guesses the contaner and codecs - c0=h264,f0=24,h0=720,w0=1280
    char *vh = regextract1(item->video,"h0=([^,]+)",1,0);
    char *vw = regextract1(item->video,"w0=([^,]+)",1,0);
    char *vf = regextract1(item->video,"f0=([^,]+)",1,0);
    char *vc = regextract1(item->video,"c0=([^,]+)",1,0);

    fprintf(xmlout,"\t<resolution>%sx%s</resolution>\n",NVL(vw),NVL(vh));
    video_field("videoSource",item->videosource,0,NULL,NULL);
    fprintf(xmlout,"\t<videoOutput>%sp %sHz</videoOutput>\n",NVL(vh),NVL(vf));
    video_field("aspect","UNKNOWN",0,NULL,NULL);
    fprintf(xmlout,"\t<fps>%s</fps>\n",NVL(vf));

    FREE(vh);
    FREE(vw);
    FREE(vf);
    FREE(vc);

    char *date_format="%y-%m-%d";
#define DATE_BUF_SIZ 40
    char date[DATE_BUF_SIZ];
    if (item->filetime) {
        strftime(date,DATE_BUF_SIZ,date_format,internal_time2tm(item->filetime,NULL));
        video_field("fileDate",date,0,NULL,NULL);
    }
    fprintf(xmlout,"\t<fileSize>%d MBytes</fileSize>\n",item->sizemb);

    //---------------------------
    if (!lean_xml) {
        if (total) fprintf(xmlout,"\t<first>%ld</first>\n",all_items[0]->id);

        if (pos>0) {
            fprintf(xmlout,"\t<previous>%ld</previous>\n",all_items[pos-1]->id);
        } else {
            fprintf(xmlout,"\t<previous>UNKNOWN</previous>\n");
        }

        if (pos<total-1) {
            fprintf(xmlout,"\t<next>%ld</next>\n",all_items[pos+1]->id);
        } else {
            fprintf(xmlout,"\t<next>UNKNOWN</next>\n");
        }
        if (total) fprintf(xmlout,"\t<last>%ld</last>\n",all_items[total-1]->id);
    }

    //---------------------------
    
    if (item->expanded_genre == NULL) {
        if(item->genre) {
            item->expanded_genre = translate_genre(item->genre,1,"|");
        }
    }

    Array *genres = splitstr(item->expanded_genre,"|");
    fprintf(xmlout,"\t<genres count=\"%d\">\n",genres->size);
    for(i = 0 ; i < genres->size ; i++ ) {
        char *g = genres->array[i];
        fprintf(xmlout,"\t\t<genre index=\"Genres_%s_1\">%s</genre>\n",g,g);
    }
    fprintf(xmlout,"\t</genres>\n");
    array_free(genres);

    //---------------------------

    yamj_people(item,"directors","director",item->directors);
    yamj_people(item,"writers","writer",item->writers);
    yamj_people(item,"cast","actor",item->actors);

    //---------------------------

    if (item->yamj_member_of) {
        int i;
        fprintf(xmlout,"\t<indexes>\n");
        for(i= 0 ; i<item->yamj_member_of->size ; i++ ) {
            int free_it;
            YAMJSubCat *sc = item->yamj_member_of->array[i];

            if (sc->owner_cat) {

                char *name=sc->name;
                char *ownername=sc->owner_cat->name;
                char *encname=url_encode_static(name,&free_it);

                fprintf(xmlout,"\t\t<index encoded=\"%s\" originalName=\"%s\" type=\"%s\">%s</index>\n",
                    encname,ownername,ownername,encname);

                if(free_it) FREE(encname);
            }

        }
        fprintf(xmlout,"\t</indexes>\n");
    }

    //----------------------------

        

    // Dont write individual file details for boxsets - these are read from the baseFilename.xml 
    if (!is_boxset || !lean_xml ) {
        yamj_files(item);
    }

    fprintf(xmlout,"</movie>\n");
    return ret;
}

void yamj_people(DbItem *item,char *tag,char *tag2,DbGroupIMDB *group)
{
    if (group) {
        EVALUATE_GROUP(group);
        if (group->dbgi_size) {
            fprintf(xmlout,"\t<%s count=\"%d\">\n",tag,group->dbgi_size);
            int i;
            for(i = 0 ; i< group->dbgi_size ; i++ ) {
                char id[20];
                sprintf(id,"%d",group->dbgi_ids[i]);
                char *record = dbnames_fetch_static(id,item->db->people_file);
                record = strchr(record,'\t');
                if (record) {
                    fprintf(xmlout,"\t\t<%s>%s</%s>\n",tag2,xmlstr_static(++record,0),tag2);
                }
            }
            fprintf(xmlout,"\t</%s>\n",tag);

        }
    }
}
void yamj_files(DbItem *item)
{
    fprintf(xmlout,"\t<files>\n");


    // For TV etc all the parts must be listed in order. So start with season -1 and repeat until all seasons done
    if (item->linked == NULL) {
        yamj_file(item,1,0);
    } else {
        // Sort all items in title/season/episode order
        DbItem **ptr = sort_linked_items(item,db_overview_cmp_by_title);

        // Now display

        int i;
        int part_no=1;
        for(i=0 ; i< item->link_count+1 ; i++ ) {
            int show_source = 0;
            if ( item->category == 'T' ) {
                if (i > 0 && db_overview_cmp_by_title(&ptr[i],&ptr[i-1]) == 0) {
                    show_source = 1;
                } else if (i < item->link_count && db_overview_cmp_by_title(&ptr[i],&ptr[i+1]) == 0) {
                    show_source = 1;
                }
            }
            part_no = yamj_file(ptr[i],part_no,show_source);
        }
        FREE(ptr);
    }
    fprintf(xmlout,"\t</files>\n");
}

/*
 * print file - returns next part no
 */
int yamj_file(DbItem *item,int part_no,int show_source)
{
    //HTML_LOG(0,"item %s %dx%s %s",NVL(item->title),item->season,NVL(item->episode),item->file);
    yamj_file_part(item,part_no++,NULL,show_source);

    if (item->parts) {

        int i;
        Array *parts = splitstr(item->parts,"/");

        for(i = 0 ; i < parts->size ; i++ ) {
            yamj_file_part(item,part_no++,parts->array[i],show_source);
        }
        array_free(parts);
    }
    return part_no;
}


void yamj_file_part(DbItem *item,int part_no,char *part_name,int show_source)
{
    if (item->category == 'T' ) {
        errno=0;
        int epno=strtol(NVL(item->episode),NULL,10);
        if (!errno) part_no = epno;
    }

    fprintf(xmlout,"\t<file firstPart=\"%d\" lastPart=\"%d\" season=\"%d\" size=\"%d\"",
            part_no,
            part_no,
            item->season,
            item->sizemb*1024*1024);

    if (!lean_xml) {
        fprintf(xmlout," subtitlesExchange=\"NO\"");
    }
    if (!lean_xml) {
        fprintf(xmlout," title=\"%s\"",((item->category=='T')?xmlstr_static(NVL(item->eptitle),0):"UNKNOWN"));
    }
    fprintf(xmlout," vod=\"\"");

    if (!lean_xml || item->watched) {
        fprintf(xmlout," watched=\"%s\"",BOOL(item->watched));
    }
    fprintf(xmlout," >\n");

    int freeit;
    char *path;

    if (part_name == NULL) {
        path = get_path(item,item->file,&freeit);
    } else {
        path = get_path(item,part_name,&freeit);
    }

    int free_enc;
    char *encoded_path = url_encode_static(path,&free_enc);

    if (!lean_xml) {
        fprintf(xmlout,"\t\t<fileLocation>%s</fileLocation>\n",xmlstr_static(path,0));
    }
    fprintf(xmlout,"\t\t<fileURL>file://%s</fileURL>\n",encoded_path);

    if (item->category == 'T' ) {
        fprintf(xmlout,"\t\t<fileTitle part=\"%d\">%s",part_no,xmlstr_static(NVL(item->eptitle),0));

        if (show_source) {
           char *sep = " - ";
           if (item->videosource) {
            char *p = util_tolower(item->videosource);
            fprintf(xmlout,"%s%s",sep,p);
            FREE(p);
            sep=",";
           }
           if (!EMPTY_STR(item->file)) {
               if (util_strcasestr(item->file,"proper")) {
                   fprintf(xmlout,"%sproper",sep);
                   sep=",";
               }
               if (util_strcasestr(item->file,"repack")) {
                   fprintf(xmlout,"%srepack",sep);
                   sep=",";
               }
           }

        }
        fprintf(xmlout,"</fileTitle>\n");

        char *plot = get_plot(item,PLOT_EPISODE);

        if (!EMPTY_STR(plot)) {
            char *p = xmlstr_static(plot,0);
            if (p && p[2] == ':' && isalpha(p[0]) && isalpha(p[1])) {
                p += 3;
            }
            fprintf(xmlout,"\t<filePlot part=\"%d\">%s%s</filePlot>\n",part_no,p,(item->watched?" (w)":""));
            FREE(plot);
        }

        if (!lean_xml || item->season == 0) {
            fprintf(xmlout,"\t\t<airsInfo part=\"%d\"",part_no);

            // not scraped yet!
            fprintf(xmlout," afterSeason=\"0\" beforeEpisode=\"0\" beforeSeason=\"0\"");
            fprintf(xmlout," >%d</airsInfo>\n",part_no);
        }


        fprintf(xmlout,"\t\t<firstAired part=\"%d\">%s</firstAired>\n",part_no,get_date_static(item,"%Y-%m-%d"));
    } else {
        if (!lean_xml) {
            fprintf(xmlout,"\t\t<fileTitle part=\"%d\">UNKNOWN</fileTitle>\n",part_no);
        }
    }
    fprintf(xmlout,"\t</file>\n");

    if (free_enc) FREE(encoded_path);
    if (freeit) FREE(path);
}

/*
 * request = input argument
 * subcat = Sub category corresponding to input
 * cat = any category for output. If it contains the current subcat then extr page info is output.
 */
int yamj_category_xml(char *request,YAMJSubCat *subcat,YAMJCat *cat,DbSortedRows *sorted_rows)
{
    int ret = 1;
    int i;

    if (subcat == NULL || !lean_xml || cat == subcat->owner_cat) {

        HTML_LOG(LOG_LVL,"cat [%s]",xmlstr_static(cat->name,0));
        fprintf(xmlout,"<category count=\"%d\" name=\"%s\">\n",cat->subcats->size,cat->name);
        for(i = 0 ; i < cat->subcats->size ; i++ ) {
            YAMJSubCat *s = cat->subcats->array[i];
            fprintf(xmlout,"\t<index name=\"%s\"",s->name);
            if (s == subcat) {

                int last = 1+(sorted_rows->num_rows/s->owner_cat->page_size);
                int first = 1;
                int next = s->page + 1;
                if (next > last) next = last;

                int prev = s->page - 1;
                if (prev < first ) prev = first;

                fprintf(xmlout,"\n\t\tcurrent=\"true\"\n");
                fprintf(xmlout,"\t\tcurrentIndex=\"%d\"\n",subcat->page);

                fprintf(xmlout,"\t\tfirst=\"%s_%s_%d\"\n",s->owner_cat->name,s->name,first);
                fprintf(xmlout,"\t\tlast=\"%s_%s_%d\"\n",s->owner_cat->name,s->name,last);
                fprintf(xmlout,"\t\tnext=\"%s_%s_%d\"\n",s->owner_cat->name,s->name,next);
                fprintf(xmlout,"\t\tprevious=\"%s_%s_%d\"\n",s->owner_cat->name,s->name,prev);
                fprintf(xmlout,"\t\tlastIndex=\"%d\"",last);
            }

            // url encode the cat_subcat_1 
            char *name,*name_enc;
            int free_it;
            ovs_asprintf(&name,"%s_%s_1",s->owner_cat->name,s->name);
            name_enc = url_encode_static(name,&free_it);
            fprintf(xmlout,">%s</index>\n",name_enc);
            if (free_it) FREE(name_enc);
            FREE(name);

        }
        fprintf(xmlout,"</category>\n");
    }
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

        HTML_LOG(LOG_LVL,"query = [%s]",query);

        ret = new_subcat(owner,name,query,1,1);
    }

    FREE(key);
    if (ret) {
        HTML_LOG(LOG_LVL,"read subcat[%d,%d] name=[%s] auto_subcat_expr_url=[%s]",num,sub,ret->name,ret->filter_expr_url);
    }
    return ret;
}

YAMJCat *yamj_cat_new(char *name,char *auto_subcat_expr_url)
{
    static int page_size = -1;

    if (page_size == -1) {
        char *p = oversight_val("ovs_yamj_page_size");
        if (!EMPTY_STR(p)) {
            page_size = atoi(p);
        } else {
            page_size = 10;
        }
        HTML_LOG(0,"page size = %d",page_size);
    }

    YAMJCat *ret = NULL;
    if (!EMPTY_STR(name)) {

        ret = CALLOC(1,sizeof(YAMJCat));

        ret->name = STRDUP(name);
        ret->auto_subcat_expr_url = STRDUP(auto_subcat_expr_url);
        ret->page_size = page_size;
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

        char *key2;
        ovs_asprintf(&key2,CONFIG_PREFIX "%d_expr",num);

        ret = yamj_cat_new(name,oversight_val(key2));
        FREE(key2);

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
        } else if ((ret->auto_subcat_expr = parse_full_url_expression(ret->auto_subcat_expr_url,TOKEN_URL)) == NULL) {
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

    YAMJCat *yc;
    while ((yc = yamj_cat_config(++i)) != NULL) {
        array_add(categories,yc);

        load_dynamic_cat(yc,db_time());
    }

    return ret;
}


char *cache_file(char *request)
{
    char *path;
    ovs_asprintf(&path,"%s/cache/%s",appDir(),request);
    return path;
}


char *dynamic_cat_file(YAMJCat *cat) {
    char *path;
    ovs_asprintf(&path,"%s/cache/%s.cat",appDir(),cat->name);
    return path;
}

void load_dynamic_cat(YAMJCat *cat,time_t index_time)
{
    if (cat->auto_subcat_expr != NULL) {
        // try to load it
        char *path = dynamic_cat_file(cat);
        time_t saved = file_time(path);
        if (saved > index_time) {
#define BUF_SIZE 999
            char buf[BUF_SIZE];
            FILE *fp = util_open(path,"r");
            if (fp) {
                while(fgets(buf,BUF_SIZE,fp) != NULL) {
                    chomp(buf);
                    HTML_LOG(0,"loaded subcat [%s][%s]->%s",cat->name,buf,path);
                    new_subcat(cat,buf,NULL,0,1);
                }
                fclose(fp);
                cat->evaluated = 1;
            } else {
                html_error("error loading cat file [%s]",path);
            }
        }
        FREE(path);
    }
}
void save_dynamic_categories(Array *categories)
{
    // Save the dynamic categories.
    if (categories) {
        int i;
        for(i = 0 ; i<categories->size ; i++) {
            save_dynamic_cat(categories->array[i]);
        }
    }
}
void save_dynamic_cat(YAMJCat *cat)
{
    if (cat->auto_subcat_expr != NULL && cat->subcats) {
        HTML_LOG(0,"FOUND [%s]",cat->auto_subcat_expr_url);
        if (cat->evaluated == 0) {
            char *path = dynamic_cat_file(cat);
            int i;
            FILE *fp = util_open(path,"w");
            if (fp) {
                for(i = 0 ; i<cat->subcats->size ; i++) {
                    YAMJSubCat *sc = cat->subcats->array[i];
                    HTML_LOG(0,"saving subcat [%s][%s]->%s",cat->name,sc->name,path);
                    fprintf(fp,"%s\n",sc->name);
                }
                fclose(fp);
            }
            FREE(path);
        }
    }
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



int yamj_categories_xml(char *request,YAMJSubCat *selected_subcat,Array *categories,DbSortedRows *sorted_rows)
{
    int ret = 1;
    int i;


    fprintf(xmlout,"<library count=\"%d\">\n",categories->size);

/*
 * if (!selected_subcat) {
        html_error("unknown request [%s]",request);
        fprintf(xmlout,"<error>see html comments</error>\n");
    }
    */

    for(i = 0 ; i < categories->size ; i++ ) {
        YAMJCat *cat = categories->array[i];
        yamj_category_xml(request,selected_subcat,cat,sorted_rows);
    }



    if (selected_subcat && sorted_rows->num_rows) {

        int num = sorted_rows->num_rows;
        fprintf(xmlout,"<movies count=\"%d\">\n",num);


        int page_size = selected_subcat->owner_cat->page_size;
        int start = (selected_subcat->page-1) * page_size;
        int end = start + page_size;

        if ( start >= num ) start = num;
        if ( end >= num ) end = num;

        HTML_LOG(0,"page %d page size = %d start = %d end = %d ",selected_subcat->page,page_size,start,end);


        for (i = start ; i < end ; i++ ) {
            DbItem *item = sorted_rows->rows[i];

            // Finish populating item->yamj_member_of with all categories this member belongs to
            // add_static_indices_to_item(item,selected_subcat,categories);

            yamj_video_xml(request,item,0,sorted_rows->rows,i,num);
        }
        fprintf(xmlout,"</movies>\n");
    }
    fprintf(xmlout,"</library>\n");
    HTML_LOG(0,"end");

    return ret;

}


/**
 * Some subcats are created on the fly eg Title_Letter_Page.xml
 * Letter is derived from database contents, as first UTF-8 character of item titles.
 * Whilst computing these the subcat items will get populated.
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
 */

/*
 * check name = Category_SubCat_Page.xml
 */
YAMJSubCat *find_subcat(char *request,Array *categories)
{
    int i,j;
    YAMJSubCat *subcat=NULL;
    int page;

    assert(request);
    assert(categories);

    Array *request_parts = split_request(request);

    if (request_parts) {

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

        if (!cat) {
            html_error("request [%s] : Category %s not found in configuration",request,cat_name);
        } else if (!subcat) {
            if (EMPTY_STR(cat->auto_subcat_expr_url)) {
                if (STRCMP(cat->name,YAMJ_QUERY_NAME) == 0) {
                    // The subcat is the temporary 'query' one created specially for Ad-Hoc query subcats.
                    // In this case the subcat name IS also the query eg.
                    // query__T~f~~e~'Lost'_1.xml = Title Field Equals Lost
                    subcat = new_subcat(cat,subcat_name,subcat_name,1,1);

                } else {
                    html_error("request [%s] : Subcategory %s not found in configuration",request,subcat_name);
                }
            } else {
                // If No subcat exists then create one using a combination of the owner_cat auto_subcat_expr_url and the
                // subcat name.
                // Eg
                //    cat->auto_subcat_expr_url = _T~f~~l~1 (1st character of title field)
                //    subcat name = B
                //    Create subcat with filter 'B'~e~_T~f~~l~1 ( 'B' = 1st character of title field )
                //
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
        array_free(request_parts);
    }

    return subcat;
}

void log_request(char *request)
{
#define REQ_LOG "/share/Apps/oversight/logs/request.log"

    if (file_size(REQ_LOG) > 1000000 ) {
        rename(REQ_LOG,REQ_LOG".old");
    }

    FILE *fp = util_open(REQ_LOG,"a");
    if (fp) {
        fprintf(fp,"[%s]\n",request);
        fclose(fp);
    }
}


int yamj_xml(char *request)
{

    int ret = 0;
    char *request_in = request;



    // request = Cat_SubCat_page.xml
    //
    //
    int do_query = util_starts_with(request,YAMJ_QUERY_PREFIX);
    int cat_index = (STRCMP(request,CATEGORY_INDEX) == 0) ;

    char *img[][3] = {
        { YAMJ_THUMB_PREFIX , "_J" , ".thumb.jpg" },
        { YAMJ_BOXSET_PREFIX , "_J" , ".thumb.boxset.jpg" },
        { YAMJ_POSTER_PREFIX , "_J" , ".jpg" },
        { YAMJ_BANNER_PREFIX , "_b" , ".jpg" },
        { YAMJ_FANART_PREFIX , "_fa" , ".jpg" },
        { NULL , NULL , NULL }};
    char *ext;


#if 0
        if (0 && util_strreg(request,"^[0-9]+.xml$",0)) {

            // Detail files not used by eversion so we wont dwell on these.
            // write movie XML
            xml_headers(stdout);
            config_read_dimensions(0);
            HTML_LOG(0,"processing [%s]",xmlstr_static(request,0));
            load_configs();
            lean_xml = (*oversight_val("ovs_yamj_lean_xml") == '1');
            fprintf(xmlout,"<details>\n");
            ret = yamj_video_xml(request,NULL,1,NULL,0,1);
            fprintf(xmlout,"</details>\n");
            log_request(request);

        } else
#endif
            
    if ( (ext = util_endswith(request,".jpg")) != NULL) {

        printf("Content-Type: image/jpeg\n\n");

        int i;
        for(i  = 0 ; img[i][0] ; i++ ) {
            //fprintf(stderr,"[%s][%s][%s] ext[%s]\n",img[i][0],img[i][1],img[i][2],ext);
            if (util_starts_with(request,img[i][0])) { 

                int redirect=0;
                char *file;
                ovs_asprintf(&file,"%s/db/global/%s/ovs_%.*s%s",
                        (redirect?"/oversight":appDir()),
                        img[i][1],
                        ext-request-strlen(img[i][0]),
                        request+strlen(img[i][0]),
                        img[i][2]);

                if (redirect) {
                    printf("HTTP/1.1 301 Permanently Moved\r\n");
                    printf("Location: %s\r\n\r\n",file);
                } else {
                    cat(NULL,file);
                }
                log_request(request);
                FREE(file);
                if (redirect) exit(301);
                break;
            }
        }

    } else if (cat_index|| do_query ||  util_endswith(request,".xml")) {
        
        xml_headers(stdout);

        int cache=1;
        char *cache_path;
        
        log_request(request);
        if (cache) {
            if (*query_val("cache") == '0') {
                cache = 0;
            }
        }
        if (cache) {
            cache_path = cache_file(".no");
            if (exists(cache_path)) {
                cache = 0;
            }
            FREE(cache_path);
        }

        if (cache) {
            cache_path = cache_file(request);
        }
        if (!cache || stale_cache_file(cache_path)) {


            xmlout = stdout;
            if (cache) {
               FILE *fp =util_open(cache_path,"w");
               if (fp) {
                   xmlout = fp;
                   html_set_output(xmlout);
               } else {
                   cache = 0;
               }
            }

            config_read_dimensions(0);
            HTML_LOG(0,"processing [%s]",xmlstr_static(request,0));
            load_configs();
            lean_xml = (*oversight_val("ovs_yamj_lean_xml") == '1');

            Array *categories = array_new(free_yamj_catetory);

            yamj_build_categories(request,categories);

            YAMJSubCat *selected_subcat = NULL;
            

            // Either use an arbitrary expression derived from request fake xml name OR use the configured expression derived from 
            // the subcategory name.
            if (do_query) { 
                
                // Add a temporary query category to contain our query sub category
                YAMJCat *temp_query_cat = yamj_cat_new(YAMJ_QUERY_NAME,NULL);
                array_add(categories,temp_query_cat);
                selected_subcat = find_subcat(request,categories);

            } else if (STRCMP(request,CATEGORY_INDEX) != 0 ) {
                selected_subcat = find_subcat(request,categories);
            }

            // Here we could have newest first but leave that to skins 
            int (*sort_fn)(DbItem **,DbItem**) = NULL;
            if (selected_subcat)  {
                if ((STRCMP(selected_subcat->name,"By Age") == 0) || (STRCMP(selected_subcat->name,"New") == 0)) {
                    if (STRCMP(selected_subcat->owner_cat->name,"Other") == 0) {
                        sort_fn = db_overview_cmp_by_age_desc;
                    }
                }
            }

            DbSortedRows *sorted_rows = get_sorted_rows(NULL,sort_fn,0,NULL,categories,selected_subcat);

            HTML_LOG(1,"Sort categories..");
            sort_categories(categories);

            yamj_categories_xml(request,selected_subcat,categories,sorted_rows);

            save_dynamic_categories(categories);
            array_free(categories);
            if (cache) {
                fclose(xmlout);
                html_set_output(stdout);
            }
        }
        if (cache) {
            if ((xmlout=fopen(cache_path,"r")) != NULL) {
                append_content(xmlout,stdout);
                fclose(xmlout);
                html_set_output(stdout);
            } else {
                fprintf(xmlout,"cache error [%s]",cache_path);
            }
        }

    } else {
        printf("Content-Type: text/plain\n\n");
        html_error("error invalid yamj request [%s] %d",xmlstr_static(request,0),STRCMP(request,CATEGORY_INDEX));
    }

    fflush(stdout);
    if (request != request_in) {
        FREE(request);
    }
    return ret;
}

// vi:sw=4:et:ts=4
