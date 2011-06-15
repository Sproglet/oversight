# functions relating to actor, director and writer
#
# The scanner has 3 phases:
# scan: scrape sites for a single movie
# queue: append single movie details to a mini-index.db file.
# merge: when a folder is finished or about 30 movies queued, merge the queue file into the main index.db file.
#
# People will be handled at each stage as follows:

# Scan Phase =====================================================

# 1. get movie details
# 2. get cast names
# 3. get cast ids using a regex to extract the id. This regex will be different for each domain but will
#         default to the the last integer in the url. 
# 4. queue images  (now referenced by oversight id not IMDB id)


# convert thumbnail url to bigger url depending on domain
function person_get_img_url(domain,url) {
    return domain_edits(domain,url,"catalog_domain_portrait_url_regex_list",0);
}

# extract person id from a url depending on the domain.
function person_get_id(domain,url) {
    return domain_edits(domain,url,"catalog_domain_url_to_personid_regex_list",0);
}


# Queue phase =======================================
# Occurs when a scan info is written to temporary file. We do not know ovsids at this point.

# returns line fragment to add to ascii database queue.
# eg. ACTORS=domain@extid1@extid2@extid3 \t WRITERS \t domain@extid6@extid7 \t _DIRECTORS domain@extid8@extid9 to queue file.

# INPUT minfo - scraped information esp [mi_actor_ids]=imdb:nm1111@nm2222 etc
# OUTPUT returns line fragment to add to queue
# also set  lookup person_extid2name[domain:id]=name
function person_add_db_queue(minfo,person_extid2name) {
    person_add_db_queue_role(minfo,"actor",person_extid2name);
    person_add_db_queue_role(minfo,"director",person_extid2name);
    person_add_db_queue_role(minfo,"writer",person_extid2name);
}

function person_add_db_queue_role(minfo,role,person_extid2name,\
i,num,domain,ids,names,key,namekey) {

    id1("person_extid2name:");

    key = "mi_"role"_ids" ;
    namekey = "mi_"role"_names" ;

    if (key in minfo) {

        # update lookup table
        num = split(minfo[key],ids,"@");
        split(minfo[namekey],names,"@");

        domain = ids[1];
        for(i = 2 ; i <= num ; i++ ) {
            person_extid2name[domain":"ids[i]] = names[i];
            INF("person_extid2name["domain":"ids[i]"] => "names[i]);
        }
    } else {
        INF("no people data");
    }
    id0();
}

# Pre-Merge phase ===================================
# Called just before a batch or 30 or so scans are added to the main index.db
#
# 1. Make sure all actor db files are updated - generating new oversight ids(ovsid) if reuqired.
# 2. Populate hash person_extid2ovsid with lookups needed for current batch.
#

# input person_extid2name = hash of [domain:extid] to actor name eg [imdb:nm0000602]=Robert Redford
# output person_extid2ovsid hash of [domain:extid] to ovsid  eg [123]=nm0000602
# sideeffect: updates various person db files.
# people.db [ maps oversight id to actor name ]
# people.domain.db [ maps external id to oversight id ] eg people.imdb.db
function people_update_dbs(person_extid2name,person_extid2ovsid,\
key,extid,ovsid,domain,tmp,peopledb,domaindb,sortfiles,name,f) {

    id1("people_update_dbs");

    for (key in person_extid2name) {

        name = person_extid2name[key];
        DEBUG(key"="name);
        split(key,tmp,":");
        domain = tmp[1];
        extid = tmp[2];

        if (domain != "" && extid != "") {

            peopledb = APPDIR"/db/people.db";
            domaindb = APPDIR"/db/people."domain".db";

            ovsid = people_db_lookup(domaindb,1,extid,2);
            if (ovsid == "") {
                ovsid = people_db_lookup(peopledb,2,name,1);
                if (ovsid == "") {
                    ovsid = people_db_add(peopledb,name);
                    sortfiles[peopledb] = 1;
                }
                people_domain_db_add(domaindb,extid,ovsid);
                sortfiles[domaindb] = 1;
            }
            person_extid2ovsid[key] = ovsid;

        }
    }
    for(f in sortfiles) {
        sort_file(f,"-u");
    }
    get_queued_portraits(person_extid2ovsid);
    id0("");
}
#now we have mapping from external id to ovsid so wecan fetch any images.
function get_queued_portraits(person_extid2ovsid,\
i,ovsid,file) {
    id1("get_queued_portraits");
    dump(0,"g_portrait_queue",g_portrait_queue);
    for(i in g_portrait_queue) {
        ovsid = person_extid2ovsid[i];
        file = APPDIR"/db/global/"ACTORS"/"g_settings["catalog_poster_prefix"] ovsid".jpg";
        get_portrait(ovsid,g_portrait_queue[i],file);
    }
    delete g_portrait_queue;
    id0();
}

function get_portrait(id,url,file,\
ret) {
    ret = 0;
    if (url && GET_PORTRAITS && !(id in g_portrait)) {
        if (UPDATE_PORTRAITS || !hasContent(file) ) {
            if (preparePath(file) == 0) {
                g_portrait[id]=1;
                #ret = exec("wget -o /dev/null -O "qa(file)" "qa(url));

                #remove ampersand from call
                ret = exec(APPDIR"/bin/jpg_fetch_and_scale "g_fetch_images_concurrently" "PID" portrait "qa(url)" "qa(file)" "g_wget_opts" -U \""g_user_agent"\"");
            }
        }
    }
    return ret;
}

# Do a full scan for a person. If this becomes a performance issue then we can
# 1. implement bchop or 2. partition the people files.
function people_db_lookup(file,infield,value,outfield,\
line,err,fields,ret) {

    while(( err = (getline line < file)) > 0) {
        if (index(line,value)) {
            split(line,fields,"\t");
            if (fields[infield] == value) {
                ret = fields[outfield];
                INF("found ["line"] in "file" "value" = "ret);
                break;
            }
        }
    }
    if (err >= 0) {
        close(file);
    }
    return ret;
}

function people_db_add(dbfile,name,\
newovsid) {

    newovsid = get_maxid(dbfile)+1;
    print newovsid"\t"name >> dbfile;
    INF("add new "dbfile": "newovsid"\t"name);
    close(dbfile);
    set_maxid(dbfile,newovsid);
    return newovsid;
}

function people_domain_db_add(domaindb,extid,ovsid) {
    print extid"\t"ovsid >> domaindb;
    INF("add new "domaindb": "extid"\t"ovsid);
    close(domaindb);
}

# 
# Merge Phase ============================================
#
# If adding a new row replace  ACTOR, DIRECTORS and WRITER fields with oversight ids.
# ie _A=domain:id1,id2,id3 with _A:ovsid1,ovsid2,ovsid3
#
function people_change_extid_to_ovsid(fields,person_extid2ovsid) {
    people_change_extid_to_ovsid_by_role(ACTORS,fields,person_extid2ovsid);
    people_change_extid_to_ovsid_by_role(DIRECTORS,fields,person_extid2ovsid);
    people_change_extid_to_ovsid_by_role(WRITERS,fields,person_extid2ovsid);
}

# INPUT db field array f[dbfield]="domain@extid1@extid2@...." dbfield=ACTORS,WRITERS,DIRECTORS
# OUTPUT f[dbfield]="ovsid1,ovsid2,..."
function people_change_extid_to_ovsid_by_role(db_field,fields,person_extid2ovsid,\
extids,ovsids,num,domain,i,key) {

    if (db_field in fields) {


        num = split(fields[db_field],extids,"@");
        domain = extids[1];
        for(i = 2 ; i <= num ; i++ ) {

            key = domain":"extids[i];
            if (key in person_extid2ovsid) {
                ovsids = ovsids "," person_extid2ovsid[key];
            }
        }

        ovsids = substr(ovsids,2);

        INF("person_extid2ovsid ["fields[db_field]"] = ["ovsids"]");
        fields[db_field] = ovsids;
    }
}
#
# Post Merge Phase =======================================
#
# person_extid2ovsid should be descoped.


function people_tmp_file(db_name) {
    return g_tmp_dir "/" db_name ".db." PID;
}

# If a new file has been created - merge it with the existing one and sort.
# We may need to specify the sort key more precisely if the id length varies.
function people_update(db_name,\
db_old,db_new) {

    db_new = people_tmp_file(db_name);
    db_old = APPDIR "/db/" db_name;

}
