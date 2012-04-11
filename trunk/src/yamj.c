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

#define YAMJ_PREFIX "yamj/"
#define CONFIG_PREFIX "ovs_yamj_cat"

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
    printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
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

int yamj_video_xml(char *request,DbItem *item)
{
    int ret = 1;
    if (item == NULL) {
        HTML_LOG(0,"TODO html log get dbitem using request details [%s]",request);
    }
    printf("<movie>\n");
    printf("</movie>\n");
    return ret;
}

/*
 * request = input argument
 * subcat = Sub category corresponding to input
 * cat = any category for output. If it contains the current subcat then extr page info is output.
 */
int yamj_category_xml(char *request,YAMJSubCat *subcat,YAMJCat *cat)
{
    int ret = 1;
    int i;

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
        printf(">%s_%s_1</index>\n",s->owner_cat->name,s->name);

    }
    printf("</category>\n");
    return ret;
}

YAMJSubCat *new_subcat(YAMJCat *owner,char *name,char *filter_url) {

    assert(owner);
    YAMJSubCat *ret = NULL;

    ret = CALLOC(sizeof(YAMJSubCat),1);
    ret->name = STRDUP(name);
    ret->owner_cat = owner;

    ret->filter_expr_url = STRDUP(filter_url);

TRACE1;
    if (EMPTY_STR(ret->filter_expr_url)) {
TRACE1;

        html_error("missing query value for subcat [%s_%s]",owner->name,name);
        free_yamj_subcatetory(ret);
        ret = NULL;

TRACE1;
    } else if ((ret->filter_expr = parse_full_url_expression(ret->filter_expr_url)) == NULL) {
TRACE1;

        html_error("unable to parse query value for [%s_%s]",owner->name,name);
        free_yamj_subcatetory(ret);
        ret = NULL;
TRACE1;
    }

TRACE1;
    if (ret) {
TRACE1;

        if (owner->subcats == NULL) {
TRACE1;
            owner->subcats = array_new(free_yamj_subcatetory);
TRACE1;
        }
TRACE1;
        array_add(owner->subcats,ret);
TRACE1;
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

        HTML_LOG(0,"query = [%s]",query);

TRACE1;
        ret = new_subcat(owner,name,query);
TRACE1;
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

TRACE1;
        int j = 0;
        while((subcat = yamj_subcat_config(ret,num,++j)) != NULL) {
            /** EMPTY LOOP **/;
        }

TRACE1;
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

int yamj_categories_xml(char *request,YAMJSubCat *subcat,Array *categories)
{
    int ret = 1;
    int i;


    printf("<library count=\"%d\">\n",categories->size);

    if (!subcat) {
        html_error("unknown request [%s]",request);
        printf("<error>see html comments</error>\n");
    }

    for(i = 0 ; i < categories->size ; i++ ) {
        yamj_category_xml(request,subcat,(YAMJCat *)(categories->array[i]));
    }


    DbItem **itemPtr;
    for (itemPtr = subcat->sorted_items ; *itemPtr ; itemPtr++ ) /* empty loop */ ;

    int count = itemPtr - subcat->sorted_items;

    printf("<movies count=\"%d\">\n",count);
    for (itemPtr = subcat->sorted_items ; *itemPtr ; itemPtr++ ) {
        DbItem *item = *itemPtr;
        yamj_video_xml(request,item);
    }
    printf("</movies>\n");
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

int compute_subcat(YAMJSubCat *subcat)
{
    assert(subcat);
    int ret = 1;

    if (!subcat->evaluated) {
        HTML_LOG(0,"TODO populate subcat db items here.");
        subcat->evaluated = 1;
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

    assert(request);
    assert(categories);

    Array *request_parts = regextract(request,pattern,0);

    if (!request_parts || request_parts->size != 4) {
        html_error("invalid request [%s] expect pattern [%s]",request,pattern);
        array_dump(0,"regex",request_parts);
    } else {

        char *cat_name = request_parts->array[1];
        char *subcat_name = request_parts->array[2];
        int page = atoi(request_parts->array[3]);


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
                subcat = new_subcat(cat,subcat_name,query);
                FREE(query);
            }
        }
    }

    array_free(request_parts);
    return subcat;
}



int yamj_xml(char *request)
{

    int ret = 1;


    if (strstr(request,YAMJ_PREFIX) == request) {

        request += strlen(YAMJ_PREFIX);

        // request = Cat_SubCat_page.xml
        //

        if ( util_strreg(request,"^[0-9]+.xml$",0)) {

            // write movie XML
            xml_headers();
            HTML_LOG(0,"processing [%s]",request);
            load_configs();
            printf("<details>\n");
            ret = yamj_video_xml(request,NULL);
            printf("</details>\n");

        } else if ( util_strreg(request,"\\.jpg$",0)) {

            // Send image
            cat(CONTENT_TYPE"image/jpeg",request);

        } else if ( util_strreg(request,"[^_]+_[^_]+_[0-9]+.xml$",0)) {

            xml_headers();
            HTML_LOG(0,"processing [%s]",request);
            load_configs();

            Array *categories = array_new(free_yamj_catetory);

            yamj_build_categories(request,categories);

            YAMJSubCat *subcat = find_subcat(request,categories);

            compute_subcat(subcat);

            yamj_categories_xml(request,subcat,categories);

        } else {
            HTML_LOG(0,"error invalid request [%s]",request);
        }
    }



    return ret;
}

// vi:sw=4:et:ts=4
