# store id of plots to be kept.
function keep_plots(fields,plot_ids,\
id) {

    id = fields_to_plot_id(fields);
    plot_ids[id] = 1;
    if (fields[CATEGORY] == "T") {
        id = plot_to_season_id(id);
        plot_ids[id] = 1;
    }
}

function queue_plots(minfo,queue_file,\
id,out) {

    id = minfo_to_plot_id(minfo);

    if (minfo["mi_category"] == "T" ) {
        if (minfo["mi_plot"]) {
            out = out plot_to_season_id(id)"\t"minfo["mi_plot"] ;
        }
        if (minfo["mi_epplot"]) {
            out = out id"\t"minfo["mi_epplot"] ;
        }
    } else {
        if (minfo["mi_plot"]) {
            out = id"\t"minfo["mi_plot"] ;
        }
    }
    if (out) {
        print out >> queue_file;
    }
    close(queue_file);
}

function get_plotline(f,parts,\
i,line) {

    delete parts;

    if ( ( getline line < f ) > 0) {
        if ((i = index(line,"\t")) != 0) {
            parts[1] = substr(line,1,i-1);
            parts[2] = substr(line,i+1);
        }
    }
}
        

function update_plots(plot_file,queue_file,plot_ids,\
action,tabs1,tabs2,total_unchanged,total_removed,total_new,total_changed,file_out) {

    id1("update_plots");
    #dump(0,"plotids",plot_ids);

    file_out = new_capture_file("plots");
    sort_file(plot_file);
    sort_file(queue_file);

    action = 3; # 0=quit 1=advance 1 2=advance 2 3=merge and advance both
    do {
        if (and(action,1)) {
            get_plotline(plot_file,tabs1);
            #DEBUG("read plot id 1["tabs1[1]"]");
        }
        if (and(action,2)) {
            get_plotline(queue_file,tabs2);
            DEBUG("read plot id 2["tabs2[1]"]");
        }

        if (tabs1[1] == "") {
            if (tabs2[1] == "") {
                # both finished
                action = 0;
            } else {
                action = 2;
            }
        } else {
            if (tabs2[1] == "") {
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
        if (action == 1) { # output tabs1[1]

            if (tabs1[1] in plot_ids) {
                if (plot_ids[tabs1[1]]++ == 1) {
                    total_unchanged++;
                    print tabs1[1]"\t"tabs1[2] >> file_out;
                }
            } else {
                total_removed ++;
            }

        } else if (action == 2 || action == 3 ) { # output tabs2[1]

            if (tabs2[1] in plot_ids) { # should always be true
                if (plot_ids[tabs2[1]]++ == 1) {
                    print tabs2[1]"\t"tabs2[2] >> file_out;

                    if (action == 2) {
                        total_new ++;
                    } else {
                        total_changed ++;
                    }
                }
            } else {
                WARNING("new plot id not present ["tabs2[1]"]");
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

function fields_to_plot_id(fields) {
    return plot_id(fields[URL],fields[TITLE],long_year(fields[YEAR]),fields[CATEGORY],fields[SEASON],fields[EPISODE]);
}

function minfo_to_plot_id(minfo) {
    return plot_id(minfo["mi_idlist"],minfo["mi_title"],minfo["mi_year"],minfo["mi_category"],minfo["mi_season"],minfo["mi_episode"]);
}

function plot_id(idlist,title,year,cat,season,episode,\
id) {
    id = get_id(idlist,"imdb",1);
    if (id == "" ) {
       if ( cat == "T" ) {
           id = get_id(idlist,"thetvdb",1);
       } else {
           id = get_id(idlist,"themoviedb",1);
       }
   }
   if (id == "" ) {
       id = get_id(idlist,"",1); # get first expression
   }
   if (id == "" ) {
       id = title"@"year;
   }
   if (cat == "T" ) {
        id = id"@"season"@"episode;
    }
    #DEBUG("plot_id ["idlist"]="id);
    return id;
}

function plot_to_season_id(id) {
    return gensub(/@[^@]*$/,"",1,id); #remove episode id
}
