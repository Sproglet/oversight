# Extract files from index.db and make a script to recreate the files.
awk '
BEGIN {
    q="'"'"'";
}

{

    # delete before file field
    tab=index($0,"_F\t");
    $0 = substr($0,tab+3);

    # delete after fiel field
    tab=index($0,"\t");
    if (tab) {
        $0 = substr($0,1,tab-1);
    }

    # re-create VIDEO_TS
    gsub(/\/$/,"/VIDEO_TS/VIDEO_TS.VOB");

    # Quote file
    gsub(q,q"\\"q q);
    $0 = q $0 q;
    $0 = "mkdir -p "$0" 2>/dev/null && rmdir "$0" 2>/dev/null && touch "$0;
    print $0;
}
' index.db
