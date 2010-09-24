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

# minfo["mi_actor_names"]="name1 \t name2 \t ...."
# minfo["mi_actor_ids"]="id1 \t id2 \t ...."
# minfo["mi_actor_domain"]="imdb" or "allocine" or "filmtotaal" etc.

# minfo["mi_writer_names"]="name1 \t name2 \t ...."
# minfo["mi_writer_ids"]="id1 \t id2 \t ...."
# minfo["mi_writer_domain"]="imdb" or "allocine" or "filmtotaal" etc.

# minfo["mi_director_names"]="name1 \t name2 \t ...."
# minfo["mi_director_ids"]="id1 \t id2 \t ...."
# minfo["mi_director_domain"]="imdb" or "allocine" or "filmtotaal" etc.

# Queue phase =======================================
# Occurs when a scan info is written to temporary file. We do not know ovsids at this point.

# Add ACTORS=domain:extid1,extid2,extid3,WRITERS \t domain:extid6,extid7 \t _DIRECTORS domain:extid8,extid9 to queue file.
# set person_extid2name[domain:id]=name

# Pre-Merge phase ===================================
# Called just before a batch or 30 or so scans are added to the main index.db
#
#  update_people_dbs():
#  for domain:extid in person_extid2name ; do
#    lookup ovsid in namedb.domain.db using extid.
#    if no present then
#       lookup ovsid in namedb.db using name
#       if not present 
#          get new ovs id
#          add [ ovsid \t name ] to namedb.db.tmp
#       endif
#       add [ extid \t ovsid ] to namedb.domain.db.tmp
#       update_people_domain[domain] = 1
#    endif
#    person_extid2ovsid[domain:extid]=ovsid
#  endfor
#
#  for all domains in update_people_domain
#      sort -u namedb.domain.db namedb.domain.db.tmp into namedb.domain.db
#      set permissions
#  endfor
#
#  if exist namedb.db.tmp then sort -u namedb.db namedb.db.tmp into namedb.db
#      set permissions
# 
# Merge Phase ============================================
#
# If adding a new row replace  ACTOR, DIRECTOR and WRITER fields with oversight ids.
# ie _A=domain:id1,id2,id3 with _A:ovsid1,ovsid2,ovsid3
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
