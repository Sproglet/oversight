// $Id:$
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "admin.h"
#include "display.h"
#include "gaya_cgi.h"
#include "template.h"


void display_admin() {

    char *action = query_val(QUERY_PARAM_ACTION);

    HTML_LOG(1,"action = %s",action);

    if (!allow_admin()) {

        printf("admin disabled");

    } else if (EMPTY_STR(action) || STRCMP(action,"ask")==0 || STRCMP(action,"Cancel")==0) {

        display_template("default","admin",0,NULL);

    } else if (util_starts_with(action,"settings")) {
        
        display_template("default","settings",0,NULL);

#define CONFIRM_PREFIX "confirm_"
    } else if (util_starts_with(action,CONFIRM_PREFIX)) {
        
        display_template("default",action+strlen(CONFIRM_PREFIX),0,NULL);

#define TEMPLATE_PREFIX "template_"
    } else if (util_starts_with(action,TEMPLATE_PREFIX)) {
        
        display_template("default",action+strlen(TEMPLATE_PREFIX),0,NULL);

    } else {

        display_template("default","completed",0,NULL);
    }

}
// vi:sw=4:et:ts=4
