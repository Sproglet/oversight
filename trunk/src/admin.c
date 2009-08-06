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

void display_admin_main_page() {

    ggg

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
