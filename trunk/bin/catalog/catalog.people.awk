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
#
# Extract the last digit.
#
#    catalog_url_to_personid_regex_list=[0-9]+[^0-9]*$,[0-9]+
#    catalog_url_to_personid_regex_list_domain=[0-9]+[^0-9]*$,[0-9]+

# 4. queue images  (now referenced by oversight id not IMDB id)

# minfo["mi_actor_names"]="\t name1 \t name2 \t ...."
# minfo["mi_actor_ids"]="\t id1 \t id2 \t ...."

# minfo["mi_writer_names"]="allocine @ name1 @ name2 @ ...."
# minfo["mi_writer_ids"]="allocine @ id1 @ id2 @ ...."

# minfo["mi_director_names"]="imdb @ name1 @ name2 @ ...."
# minfo["mi_director_ids"]="imdb @ id1 @ id2 @ ...."

# minfo = scraped information so far
# domain is site being scanned - eg imdb , moviemeter etc.
# role = actor,writer,director
# text = html text for a single actor. this may be
#    1. just a name
#    2. <a href="actor profile">actor name</a>
#    3. <a href="actor profile"><img src=portrait></a>
#
# For now we will ignore portraits - they are best scraped from bio page.
#
# return 1=info extracted 0=no info found

function person_scan(minfo,domain,role,text,\
lctext,person_name,url,external_id,ret) {

    id1("person_scan:"text);
    lctext =  tolower(text);
    if (index(lctext,"href=")) {
        if (index(lctext,"<img")) {
            INF("ignoring portrait link for now");
        } else {
            person_name = extractTagText(text,"a");
            url =  extractAttribute(text,"a","href");
            external_id=person_get_id(url);
     else {
        # just a name
        person_name = external_id = trim(text);
    }
    if(person_name != "" && external_id != "") {
        ret = 1;
        if (! ("mi_"role"_names" in minfo) ) {
            minfo["mi_"role"_names"]  = domain;
            minfo["mi_"role"_ids"]  = domain;
        }
            
        minfo["mi_"role"_names"]  = minfo["mi_"role"_names"] "@" person_name;
        minfo["mi_"role"_ids"]  = minfo["mi_"role"_ids"] "@" external_id;
    }
    id0(ret);
    return ret;
}

function person_get_id(domain,url,\
external_id,i,num,patterns,plist) {

    id1("person_get_id:"url);

    if(url) {
        domain_load_settings("default");
        domain_load_settings(domain);


        plist=g_settings[domain":catalog_url_to_personid_regex_list"];
        if (plist == "") {
            plist=g_settings["default:catalog_url_to_personid_regex_list"];
        }

        num = split(plist,patterns,",");
        for(i = 1 ; i <= num ; i++ ) {
            if (match(url,patterns[i])) {
                url = substr(url,RSTART,RLENGTH);
            }
        }
    }
    id0(url);
    return url;

}

# Queue phase =======================================
# Occurs when a scan info is written to temporary file. We do not know ovsids at this point.

# returns line fragment to add to ascii database queue.
# eg. ACTORS=domain@extid1@extid2@extid3 \t WRITERS \t domain@extid6@extid7 \t _DIRECTORS domain@extid8@extid9 to queue file.

# INPUT minfo - scraped information esp [mi_actor_ids]=imdb:nm1111@nm2222 etc
# OUTPUT returns line fragment to add to queue
# also set  lookup person_extid2name[domain:id]=name
function person_add_db_queue(minfo,person_extid2name,\
db_text) {
    db_text = "\t" person_add_db_queue_role(minfo,"actor",ACTORS,person_extid2name);
    db_text = db_text "\t" person_add_db_queue_role(minfo,"director",DIRECTORS,person_extid2name);
    db_text = db_text "\t" person_add_db_queue_role(minfo,"writer",WRITERS,person_extid2name) "\t" ;

    sub(/^\t+/,"",db_text);
    gsub(/\t\t+/,"\t",db_text);
    return db_text;
}

function person_add_db_queue_role(minfo,role,dbfield,person_extid2name,\
text,i,num,domain,ids,names) {
    text = minfo["mi_"role"_ids"] ;
    if (text) {
        text = dbfield "\t" text;

        # update lookup table
        num = split(minfo["mi_"role"_ids"],ids,"@");
        split(minfo["mi_"role"_names"],names,"@");

        domain = ids[1];
        for(i = 2 ; i <= num ; i++ ) {
            person_extid2name[domain":"role":"ids[i]] = names[i];
        }
    }
    return text;
}

# Pre-Merge phase ===================================
# Called just before a batch or 30 or so scans are added to the main index.db
#
# 1. Make sure all actor db files are updated - generating new oversight ids(ovsid) if reuqired.
# 2. Populate hash person_extid2ovsid with lookups needed for current batch.
#

# input person_extid2name = hash of [domain:role:extid] to actor name eg [imdb:actor:nm0000602]=Robert Redford
# output person_extid2ovsid hash of [domain:role:extid] to ovsid  eg [123]=nm0000602
# sideeffect: updates various person db files.
# actor.db writer.db director.db [ maps oversight id to actor name ]
# actor.domain.db [ maps external id to oversight id ] eg actor.imdb.db or writer.allocine.db
function people_update_dbs(person_extid2name,person_extid2ovsid,\
extid,domain,role,tmp,roledb,domaindb,sortfiles) {

    for (extid in person_extid2name) {

        split(extid,tmp,":");
        domain = tmp[1];
        role = tmp[2];
        extid = tmp[3];
        if (domain != "" && extid != "") {

            roledb = DBDIR"/"role"."db;
            domaindb = DBDIR"/"role"."domain"."db;

            ovsid = people_db_lookup(domaindb,1,extid,2);
            if (ovsid == "") {
                ovsid = people_db_lookup(roledb,2,name,1);
                if (ovsid == "") {
                    ovsid = people_db_add(roledb,name);
                    sortfiles[roledb] = 1;
                }
                people_domain_db_add(domaindb,extid,ovsid);
                sortfiles[domaindb] = 1;
            }
            person_extid2ovsid[domain":"role":"extid] = ovsid;
        }
    }
    for(f in sortfiles) {
        sort_file(f,"");
    }
}

# Do a full scan for a person. If this becomes a performance issue then we can
# 1. implement bchop or 2. partition the people files.
function people_db_lookup(file,infield,value,outfield,\
line,err,fields.ret) {

    while(( err = (getline line < file)) > 0) {
        split(line,fields);
        if (fields[infield] == value) {
            ret = fields[outfield];
        }
    }
    if (err == 0) {
        close(file);
    }
    return ret;
}

function people_db_add(dbfile,name,\
newovsid) {
    newovsid = get_maxid(dbfile)+1;
    print newovsid"\t"name >> dbfile;
    close(dbfile);
    set_maxid(dbfile,newovsid);
}

function people_domain_db_add(domaindb,extid,ovsid) {
    print extid"\t"ovsid >> dbfile;
    close(dbfile);
}

# 
# Merge Phase ============================================
#
# If adding a new row replace  ACTOR, DIRECTORS and WRITER fields with oversight ids.
# ie _A=domain:id1,id2,id3 with _A:ovsid1,ovsid2,ovsid3
#
function people_change_extid_to_ovsid(fields,person_extid2ovsid) {
    people_change_extid_to_ovsid_by_role("actor",ACTORS,fields,person_extid2ovsid);
    people_change_extid_to_ovsid_by_role("director",DIRECTORS,fields,person_extid2ovsid);
    people_change_extid_to_ovsid_by_role("writer",WRITERS,fields,person_extid2ovsid);
}

function people_change_extid_to_ovsid_by_role(role,db_field,fields,person_extid2ovsid,\
extids,ovsids,num,domain,i,key) {

    if (db_field in fields) {

        id1("person_extid2ovsid" fields[db_field]);

        num = split(fields[db_field],extids,"@");
        domain = extids[1];
        for(i = 2 ; i <= num ; i++ ) {

            key = domain":"role":"extids[i];
            if (key in person_extid2ovsid) {
                ovsids = ovsids "," person_extid2ovsid[key];
            }
        }

        ovsids = substr(ovsids,2);

        id0(ovsids);
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
