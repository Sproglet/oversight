# store id of plots to be kept.
function keep_plots(fields,plot_ids,\
key) {

    key = fields_to_plot_id(fields);
    plot_ids[key] = 1;
    if (fields[CATEGORY] == "T") {
        key = fields_to_season_id(fields);
        plot_ids[key] = 1;
    }
}

function queue_plots(minfo,queue_file) {

    if (minfo["mi_category"] == "T" ) {
        if (minfo["mi_plot"]) {
            print minfo_to_season_id(minfo)"\t"minfo["mi_plot"] >> queue_file;
        }
        if (minfo["mi_epplot"]) {
            print minfo_to_plot_id(minfo)"\t"minfo["mi_epplot"] >> queue_file;
        }
    } else {
        if (minfo["mi_plot"]) {
            print minfo_to_plot_id(minfo)"\t"minfo["mi_plot"] >> queue_file;
        }
    }
    close(queue_file);
}

function update_plots(plot_file,queue_file,plot_ids,\
action,row1,row2,tabs1,tabs2,total_unchanged,total_removed,total_new,total_changed,file_out) {

    id1("update_plots");
    #dump(0,"plotids",plot_ids);

    file_out = new_capture_file("plots");
    sort_file(plot_file);
    sort_file(queue_file);

    action = 3; # 0=quit 1=advance 1 2=advance 2 3=merge and advance both
    do {
        if (and(action,1)) {
            getline row1 < plot_file;
            split(row1,tabs1,"\t");
            INF("read plot id 1["tabs1[1]"]");
        }
        if (and(action,2)) {
            getline row2 < queue_file;
            split(row2,tabs2,"\t");
            INF("read plot id 2["tabs2[1]"]");
        }

        if (row1 == "") {
            if (row2 == "") {
                # both finished
                action = 0;
            } else {
                action = 2;
            }
        } else {
            if (row2 == "") {
                action = 1;
            } else {
                # We compare the id
                if ( tabs1[1] == tabs2[1]) {

                    action = 3;

                } else if (tabs1[1] < tabs2[1]) {
                    action = 1;
                } else {
                    action = 2;
                }
            }
        }
        if (action == 1) { # output row1
            if (tabs1[1] in plot_ids) {
                if (plot_ids[tabs1[1]]++ == 1) {
                    total_unchanged++;
                    print row1 >> file_out;
                }
            } else {
                total_removed ++;
            }
            row1 = "";
        } else if (action == 2) { # output row2

            if (tabs2[1] in plot_ids) { # should always be true
                if (plot_ids[tabs2[1]]++ == 1) {
                    total_new++;
                    print row2 >> file_out;
                }
            }
            row2 = "";
        } else if (action == 3) { # update

            if (tabs2[1] in plot_ids) { # should always be true
                if (plot_ids[tabs2[1]]++ == 1) {
                    total_changed ++;
                    print row2 >> file_out;
                }
            } else {
                total_removed++;
            }
        }

    } while (action > 0);
    close(plot_file);
    close(queue_file);
    close(file_out);
    touch_and_move(file_out,plot_file);
    set_permissions(qa(plot_file));
    rm(queue_file);


    INF("update_plots  database:["plot_file"]  unchanged:"total_unchanged" changed "total_changed" new "total_new" removed:"total_removed);
    id0();
}

function minfo_to_plot_id(minfo) {
    if (minfo["mi_category"] == "T" ) {
        return minfo_to_season_id(minfo)"@"minfo["mi_episode"];
    } else {
        return minfo["mi_title"]"@"minfo["mi_year"];
    }
}

function fields_to_plot_id(fields) {
    if (fields[CATEGORY] == "T" ) {
        return fields_to_season_id(fields)"@"fields[EPISODE];
    } else {
        return fields[TITLE]"@"long_year(fields[YEAR]);
    }
}

function minfo_to_season_id(minfo) {
    return minfo["mi_title"]"@"minfo["mi_year"]"@"minfo["mi_season"];
}
function fields_to_season_id(fields) {
    DEBUG("XXX TODO decode year");
    return fields[TITLE]"@"long_year(fields[YEAR])"@"fields[SEASON];
}
