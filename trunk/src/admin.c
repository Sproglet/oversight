#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "admin.h"
#include "display.h"
#include "gaya_cgi.h"

void display_admin() {

    char *action = query_val("action");

    html_log(0,"action = %s",action);

    if (!allow_admin()) {

        printf("admin disabled");

    } else if (strcmp(action,"ask")==0 || strcmp(action,"Cancel")==0) {

        display_template("default","admin",0,NULL);

    } else if (util_starts_with(action,"settings")) {
        
        display_template("default","settings",0,NULL);

    } else if (strcmp(action,"rescan_confirm") == 0) {
        
        display_template("default","rescan",0,NULL);

    } else {

        display_template("default","completed",0,NULL);
    }

}
