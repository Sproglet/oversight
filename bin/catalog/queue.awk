# This module has functions that initially move the scanned information into the various database files index.db, people, plot

function queue_minfo(minfo,qfile,person_extid2name,\
fld,line) {
    INF("queue:queue_minfo:"minfo[NAME]);

    person_add_db_queue(minfo,person_extid2name);

    # Write DIR and NAME first for easy sorting.
    line = line SUBSEP DIR SUBSEP minfo[DIR] ;
    line = line SUBSEP NAME SUBSEP minfo[NAME] ;

    for(fld in minfo) {
        if (fld != DIR && fld != NAME && fld !~ /_source$/ && fld !~ /^mi_visited/ ) {
            line = line SUBSEP fld SUBSEP minfo[fld] ;
        }
    }
    if (index(line,"\n")) gsub(/\n/,"\\n",line);
    print substr(line,2) >> qfile;
}

function read_minfo(qfile,minfo,\
line,i,tmp,num) {
    delete minfo;
    while ((getline line < qfile ) > 0 ) {
        #INF("queue: line=["line"]");
        if (index(line,SUBSEP) ) {

            #reinstate CR
            if (index(line,"\\n")) {
                gsub(/\\n/,"\n",line);
            }

            num = split(line,tmp,SUBSEP);
            for(i = 1 ; i<=num ; i+= 2) {
                minfo[tmp[i]] = tmp[i+1];
                #DEBUG("readq "db_fieldname(tmp[i])"=["tmp[i+1]"]");
            }

            if (!(FILE in minfo)) minfo[FILE] = minfo[DIR]"/"minfo[NAME];

            #INF("read "num" fields minfo media = "minfo[NAME]);
            return num;
            break;
        }
    }
    close(qfile);
    #DEBUG("eof:"file);
    return num;
}


function merge_queue(qfile,person_extid2name,\
total) {

    if (g_opt_dry_run) {

        INF("Database update skipped - dry run");

    } else {

        if(lock(g_db_lock_file)) {
            total += sort_and_merge_index(INDEX_DB,qfile,INDEX_DB_OLD,person_extid2name);
            unlock(g_db_lock_file);
        }
    }
    rm(qfile);
    delete person_extid2name;
    return total;
}

# Merge two index files together
function sort_and_merge_index(dbfile,qfile,file1_backup,person_extid2name,\
file1_sorted,file_merged,person_extid2ovsid,total) {

    id1("sort_and_merge_index ["dbfile"]["qfile"]["file1_backup"]");

    file1_sorted = new_capture_file("dbsort");
    file_merged =  new_capture_file("dbmerge");

    if (sort_index(dbfile,file1_sorted) )  {

        if (sort_file(qfile) )  {

            if (!STANDALONE) {
                people_update_dbs(person_extid2name,person_extid2ovsid);
            }

            total = merge_index(file1_sorted,qfile,file_merged,person_extid2ovsid);
            if (total) {

                replace_database_with_new(file_merged,dbfile,file1_backup);
            }
            
        }
    }
    rm(file1_sorted); 
    rm(qfile); 
    rm(file_merged);
    id0("");
    return total;
}

function merge_index(dbfile,qfile,file_out,person_extid2ovsid,\
row1,row2,fields1,fields2,action,max_id,total_unchanged,total_changed,total_new,total_removed,ret,plot_ids,changed_line) {

    id1("merge_index ["dbfile"]["qfile"]");

    #exec("cat "qa(qfile),1);
    #INF("---------------------");


    max_id = get_maxid(INDEX_DB);

    action = 3; # 0=quit 1=advance 1 2=advance 2 3=merge and advance both
    row2 = 0;
    do {
        #INF("read action="action);
        if (and(action,1)) { 
            row1 = get_dbline(dbfile);
            parseDbRow(row1,fields1,1);
            #DEBUG("OLD    :["fields1[FILE]"]");
        }
        if (and(action,2)) {
            if (read_minfo(qfile,fields2)) {
                row2=1;
                INF("Merge item    :["fields2[FILE]"]");
            }
        }

        if (row1 == "") {
            if (!row2) {
                # both finished
                action = 0;
            } else {
                action = 2;
            }
        } else {
            if (!row2) {
                action = 1;
            } else {
                # We compare the FILE field 

                if (fields1[FILE] == fields2[FILE]) {

                    action = 3;

                } else if (fields1[FILE] < fields2[FILE]) {
                    action = 1;
                } else {
                    action = 2;
                }
            }
        }

        changed_line = "";

        #DEBUG("merge action="action);
        if (action == 1) { # output row1
            if (keep_dbline(fields1)) {
                total_unchanged++;
                print row1 >> file_out;
                keep_plots(fields1,plot_ids);
            } else {
                total_removed ++;
            }
            row1 = "";
        } else if (action == 2) { # output row2

            if (keep_dbline(fields2)) {

                changed_line = ++max_id;
                total_new++;
            }
            row2 = 0;
        } else if (action == 3) { # merge
            # Merge the rows.
            fields2[WATCHED] = fields1[WATCHED];
            fields2[LOCKED] = fields1[LOCKED];
            fields2[FILE] = short_path(fields2[FILE]);

            if (keep_dbline(fields2)) {
                changed_line = fields1[ID];
                total_changed ++;
            } else {
                total_removed++;
            }
            row1 = "";
            row2 = 0;
        }

        if (changed_line != "") {
            fields2[ID] = changed_line;
            keep_plots(fields2,plot_ids);
            queue_plots(fields2,g_plot_file_queue);
            # change the external actor ids to oversight ids
            people_change_extid_to_ovsid(fields2,person_extid2ovsid);

            # TODO Pass plot. Change to use minfo ? - this may update the NFO field.
            generate_nfo_file_from_fields(g_settings["catalog_nfo_format"],fields2,0,1);

            write_dbline(fields2,file_out,1);

            # Now the ovsid is known - get images.
            get_images(fields2);

            new_content(fields2);
        }


    } while (action > 0);

    close(dbfile);
    close(qfile);
    close(file_out);
    close(g_plot_file_queue);

    set_maxid(INDEX_DB,max_id);

    if (!STANDALONE){
        update_plots(g_plot_file,g_plot_file_queue,plot_ids);
    }
    rm(g_plot_file_queue);

    INF("merge complete database:["file_out"]  unchanged:"total_unchanged" changed "total_changed" new "total_new" removed:"total_removed);
    ret = total_changed + total_new;
    id0(ret);
    return ret;
}
function set_maxid(file,max_id,\
filemax) {
    filemax = file".maxid";
    print max_id > filemax;
    close(filemax);
    INF("set_maxid["file"]="max_id);
}


function get_maxid(file,\
max_id,line,fields,filemax,tab) {
    max_id = 0;
    filemax = file".maxid";

    if (!is_file(filemax)) {
        if (is_file(file)) {
            if (file == INDEX_DB ) {
                # get mex id from main database index.db - using field _ID
                while ((line = get_dbline(file) ) != "") {
                    parseDbRow(line,fields,0);
                    if (fields[ID]+0 > max_id+0) {
                        max_id = fields[ID];
                    }
                }
            } else {
                # id is the first field
                while ((getline line < file ) > 0) {
                    if ((tab = index(line,"\t")) > 0) {
                        line = substr(line,1,tab-1);
                        if (index(line,"nm") == 1) {
                            #remove imdb nm prefix
                            line = substr(line,3);
                        }
                        if (line + 0 > max_id+0) {
                            max_id = line;
                        }
                    }
                    max_id = fields[1];
                }
            }
            close(file);
        }
        set_maxid(file,max_id);

    } else {
        getline max_id < filemax;
        close(filemax);
        max_id += 0;
        INF("get_maxid["file"]="max_id);
    }
    return max_id;
}


