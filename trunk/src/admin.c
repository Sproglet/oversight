#include <stdio.h>
#include <stdlib.h>

#include "admin.h"
#include "display.h"


void display_confirm(char *name,char *val_ok,char *va_cancel) {

    printf("<table width=100%><tr><td align=center>");
    printf("<input name=\"%s\" value=\"%s\">",name,val_ok);
    printf("</td><td align=center>");
    printf("<input name=\"%s\" value=\"%s\">",name,val_cancel);
    printf("</td></tr></table>");
}

void display_admin_rescan_confirm() {

    printf("Scan paths: %s  <p>This will return immediately and start a background"
    "scan which will complete in 15-60 minutes (depending on number of videos)."
    "<br>Internet bandwidth (esp torrent upload) also affects overall scan speed.",
    catalog_val("catalog_scan_paths"))
    display_confirm("action","rescan","Cancel");
}

void display_admin_settings() {

    char *cmd;
    ovs_asprintf(&cmd,"cd \"%s\" && ./options.sh TABLE2 \"help/%s.%s\" \"%s\" HIDE_VAR_PREFIX=1",
            appDir(),query_val("file"),query_val("help"));
    add_hidden("file");
    display_confirm("action","Save Settings","Cancel");
}

char *get_cfg_link(char *config_file,
        char *help_suffix,
        char *attr,
        char *label) {
    char *p,*link;

    ovs_asprintf(p,"action=settings&file=%s&help=%s",config_file,help_suffix);


    link= get_self_link(p,attr,label);
    FREE(p);
    return link;
}


char *get_screen_config_row(char *label,char *config_label,char *class) {
    char *attr;
    char *help_suffix;
    char *poster_help_suffix;
    char *detail_help_suffix;
    char *result = NULL;

    ovs_asprintf(attr,"class=%s",class);
    ovs_asprintf(help_suffix,"%s.help",config_label);
    ovs_asprintf(poster_help_suffix,"%s-poster.help",config_label);
    ovs_asprintf(detail_help_suffix,"%s-detail.help",config_label);

    char *help_link =
        get_cfg_link("oversight.cfg",help_suffix,class,"text mode");

    char *poster_help_link =
        get_cfg_link("oversight.cfg",poster_help_suffix,class,"poster mode");

    char *detail_help_link =
        get_cfg_link("oversight.cfg",detail_help_suffix,class,"detail view");

    ovs_asprintf(&result,
            "<table><tr><td width=25%>%s</td>"
            "<td width=25%>%s</td>"
            "<td width=25%>%s</td>"
            "<td width=25%>%s</td></tr></table>",
            label,help_link,poster_help_link,detail_help_link);


    FREE(attr);
    FREE(help_suffix);
    FREE(poster_help_suffix);
    FREE(detail_help_suffix);
    FREE(help_link);
    FREE(poster_help_link);
    FREE(detail_help_link);
    return result;
}


void display_admin_main_page() {
}

void display_admin() {

    char *action = query_val("admin");

    char *back_text = get_theme_image_link("action=ask","","back","");

    if (!allow_admin()) {

        printf("admin disabled");

    } else if (strcmp(action,"ask")==0 || strcmp(action,"Cancel")==0) {

        display_admin_main_page();

    } else if (util_starts_with(action,"settings")) {
        
        display_admin_settings() ;
        
    } else if (strcmp(action,"rescan_confirm") == 0) {
        
        display_admin_rescan_confirm();

    } else if (strcmp(action,"rescan") == 0) {

        printf("A rescan has been scheduled");

    } else {
        printf("%s completed",action);
    }

    FREE(back_text);
}
