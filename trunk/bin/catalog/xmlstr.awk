# Very basic scanning of XML in string form. Building a dom
# in awk has bad performance.

# Use this to chop by element names
# IN xmlstr - the XML string
# OUT bits
# IN regex eg 'Episode' or 'Episode|Series' regex becomes '<(REGEX)\\>'
function xml_chop(xmlstr,regex,bits) {
    return split(xmlstr,bits,"</("regex")\\>");
}

# Change array index for each bit according to text value of tag within
# Indexed items have extra "0 SUBSEP" at start to differentiate from unindexed
# this allows multiple calls to reindex.
function xml_reindex(bits,taglist,\
i,j,t,tags,regex,key,val,add,str) {

    t = split(taglist,tags," ");

    for(i = 1 ; i <= t ; i++ ) {
        regex[i] = xml_textre(tags[i]);
    }
    dump(0,"regexs",regex);
    
    for(i  in bits) {
        if (!index(i,SUBSEP)) {
            key=0;
            add=1;

            str=bits[i];

            for(j = 1 ; j <= t ; j++ ) {
                if (match(str,regex[j],val)) {
                    key= key SUBSEP val[1];
                } else {
                    INF("no match for "regex[j]" in "str);
                    add=0;
                    break;
                }
            }

            if (add) {
                bits[key] = bits[i];
                delete bits[i];
            }
        }
    }
}

function xml_textre(tag) {
    if (tag && !index(tag,"<")) {
        return "<"tag"\\>[^>]*>([^<]*)";
    }
}

function xml_extract(str,tag,\
val) {
    if (match(str,xml_textre(tag),val)) {
        return val[1];
    }
}
