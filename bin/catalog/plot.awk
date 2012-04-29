# store id of plots to be kept.
function keep_plots(fields,plot_ids,\
id) {

    id = plot_id(fields);
    plot_ids[id] = 1;
    if (fields[CATEGORY] == "T") {
        id = plot_to_season_id(id);
        plot_ids[id] = 1;
    }
}

function queue_plots(minfo,queue_file,\
id,out) {

    id = plot_id(minfo);
    if (index(minfo[PLOT],"\n")) gsub(/\n/,"\r",minfo[PLOT]); # \n messes up sort

    if (minfo[CATEGORY] == "T" ) {
        if (minfo[PLOT]) {
            out = out plot_to_season_id(id)"\t"minfo[PLOT] "\n" ;
        }
        if (index(minfo[EPPLOT],"\n")) gsub(/\n/,"\r",minfo[EPPLOT]); # \n messes up sort
        if (minfo[EPPLOT]) {
            out = out id"\t"minfo[EPPLOT] "\n" ;
        }
    } else {
        if (minfo[PLOT]) {
            out = id"\t"minfo[PLOT] "\n" ;
        }
    }
    if (out) {
        printf "%s",out >> queue_file;
    }
    #close(queue_file); - closed in calling loop
}

function get_plotline(f,parts,\
i,line) {

    delete parts;

    while ( ( getline line < f ) > 0) {
        if ((i = index(line,"\t")) > 1) { # make sure something before tab
            parts[1] = substr(line,1,i-1);
            parts[2] = substr(line,i+1);
            break;
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
            #if(LD)DETAIL("read plot id 1["tabs1[1]"]");
        }
        if (and(action,2)) {
            get_plotline(queue_file,tabs2);
            #if(LD)DETAIL("read plot id 2["tabs2[1]"]");
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
                    #if(LD)DETAIL("add plot "tabs2[1]"\t"substr(tabs2[2],1,20)"....");

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

    if(LD)DETAIL("update_plots  database:["plot_file"]  unchanged:"total_unchanged" changed "total_changed" new "total_new" removed:"total_removed);
    id0();
}

function plot_id(fields,\
idlist,id) {

    idlist=fields[IDLIST];

    id = get_id(idlist,"imdb",1);
    if (id == "" ) {
       if ( fields[CATEGORY] == "T" ) {
           id = get_id(idlist,"thetvdb",1);
       } else {
           id = get_id(idlist,"themoviedb",1);
       }
   }
   if (id == "" ) {
       id = get_id(idlist,"ovs",1);
       if (id == "" ) {
           # Special case - if no ID then add ovs:id to the idlist.
           # This is duplication of the ID field but simplifies the code
           # that looks up plot ids.
           minfo_set_id("ovs",fields[ID],fields);
           idlist=fields[IDLIST];
           id = get_id(idlist,"ovs",1);
       }
   }
   if (id == "" ) {
       id = get_id(idlist,"",1); # get first expression
   }
   if (fields[CATEGORY] == "T" ) {
        id = id"@"fields[SEASON]"@"fields[EPISODE];
   }
   return id;
}

function plot_to_season_id(id) {
    return gensub(/@[^@]*$/,"",1,id); #remove episode id
}
