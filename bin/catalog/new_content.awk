function new_content(fields\
,badfile,f,cmd,key) {

    badfile=".";

    if (g_new_content_script == "") {
        g_new_content_script = g_settings["catalog_new_content_script"];
        if (!match(g_new_content_script,"^/")) {
            g_new_content_script = OVS_HOME "/bin/" g_new_content_script;
        }
        if ( !is_file(g_new_content_script)) {
            INF("new content script ["g_new_content_script"] ignored");
            g_new_content_script = badfile;
        }
    }
    if (g_new_content_script != badfile) {
        cmd=qa(g_new_content_script);
        cmd="OVS_OVS_HOME="qa(OVS_HOME)" sh "cmd;

        for (f in fields) {
            if (f in g_db_field_name) {
                key = g_db_field_name[f];
            } else {
                key = f;
            }
            cmd = "OVS_"toupper(key)"="qa(to_string(f,fields[f]))" "cmd;
        }
        exec(cmd);
    }
}
