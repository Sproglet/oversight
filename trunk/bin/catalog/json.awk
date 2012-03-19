# real json content from url into array.
function fetch_json(url,label,out,\
f,line,ret,json) {
    ret = 0;
    f=getUrl(url,label".json",1);
    if (f) { 
        FS="\n";
        while(enc_getline(f,line) > 0) {
            json = json " " line[1];
        }
        enc_close(f);
        ret = json_parse(json,out);
    }
    return ret;
}

#
# {"name1":value , 
#   "name2":{ "first":"joe" , "last":"blogs"},
#   "nums: [2;3;4];
#   "images: [ { height: ... } { ....} { ....} 
#  } 

# becomes:
#
# a["name1"] = value;   
# a["name2:first"] = "joe";
# a["nums:1"] = 2;
# a["nums:2"] = 3;
# a["nums:3"] = 4;
# a["images:1:height"] = 400; etc.

# IN json string. no line breaks
# OUT array.

function json_parse(input,out,\
context) {
    delete out;
    context["dbg"] = 1;
    context["in"] = input;
    context["pos"] = 1;
    json_parse_object(context,out);
    return context["err"] == "";
}

function json_err(context,msg) {
    context["err"] = context["err"] msg;
    ERR("json:"msg" parsing ["substr(context["in"],context["pos"],50)"...]");
}

function ltrim(context,\
ch,i) {

    #if (index(" \t",substr(context["in"],1,1))) {
    i = context["pos"]; 
    while(1) {
        ch = substr(context["in"],i,1);

        if (ch != " " && ch != "\t" ) break;

        i++;
    }
    context["pos"] = i; 
}

function currch(context) {
    return substr(context["in"],context["pos"],1);
}

function advance(context,ch,optional) {
    if (currch(context) == ch) {
        context["pos"]++;
        return 1;
    } else if (!optional) {
        json_err(context," expected character ["ch"]");
        return 0;
    }
}

function json_parse_string(context,\
q,b,part,ch,ctx_string,ctx_pos,ctx_in,err) {

    ctx_string = context["string"] = "";

    if (advance(context,"\"")) {
        ctx_pos = context["pos"];
        ctx_in = context["in"];
        while(1) {
            # get next quote
            q = index(substr(ctx_in,ctx_pos),"\"");
            if (q == 0) {
                err="missing end quote";
                break;
            } 

            part = substr(ctx_in,ctx_pos,q-1);

            #if string contains backtick check it is not a quote
            b = index(part,"\\");
            if (b == 0) {
                # no quotes - done
                ctx_string = ctx_string part;
                ctx_pos += q;
                context["type"] = "string";
                break;
            } else {
                ch = substr(part,b+1,1);
                if (ch == "t" ) ch = "\t";
                else if (ch == "n" ) ch = "\n";

                ctx_string = ctx_string substr(ctx_in,ctx_pos,b-1) ch;
                ctx_pos += b+1;
            }
        }
        context["string"] = ctx_string;
        context["pos"] = ctx_pos;
        context["in"] = ctx_in;
        if (err) {
            json_err(context,err);
        }
    }
}

function json_push_tag(prefix,tag,context) {
    if (context["tag"]) {
        context["tag"]= context["tag"] prefix tag;
    } else {
        context["tag"]= tag;
    }
}

function json_pop_tag(context) {
    #t = context["tag"];
    #i = length(t);
    #while(i && index(":#",substr(t,i,1)) == 0) i--;
    #context["tag"] = substr(tag,1,i-1);
    sub("(^|[:#])[^:#]+$","",context["tag"]);
}

# IN json string.
# IN/OUT array.
# Return remaining string

function json_parse_object(context,out,\
label) {

    if (context["err"] ) return ;

    ltrim(context);

    if (advance(context,"{")) {

        while(!context["err"]) {

            ltrim(context);

            if (context["err"]) break;

            if (currch(context) != "\"" ) break;

            json_parse_string(context);
            if (context["err"]) break;

            label = context["string"];

            ltrim(context);

            if (!advance(context,":")) break;

            json_push_tag(":",label,context);

            #json_dbg(context,"begin parse value ["substr(context["in"],context["pos"],50)"...]");
            json_parse_value(context,out);
            if (context["err"]) break;
            #json_dbg(context,"end parse value ["substr(context["in"],context["pos"],50)"...]");
            json_assign_value_to_tag(context,out);
            
            # Remove last tag
            json_pop_tag(context);

            ltrim(context);

            #INF("END FIELD AT "substr(context["in"],context["pos"],50)"....");
            if (!advance(context,",",1)) break;
        }
        if (advance(context,"}")) {
            context["type"] = "object";
        } else {
            json_err(context,"expected \" or } ");
        }
    ;

    }
}

function json_parse_value(context,out,\
ch) {

    ltrim(context);

    delete context["type"];
    delete context["value"];

    ch=currch(context);

    if (ch == "[" ) {

        json_parse_array(context,out);

    } else if (ch == "{" ) {

        json_parse_object(context,out);

    } else if (ch == "\"" ) {

        # string

        json_parse_string(context);
        if (context["err"]) break;
        context["value"] = context[context["type"]];

    } else if (index("-+0123456789.eE",ch) && match(substr(context["in"],context["pos"]),"^[-+0-9.eE]+") ) {

        # number
        context["type"] = "number";
        context[context["type"]]  = 0+substr(context["in"],context["pos"]+RSTART-1,RLENGTH);
        context["value"] = context[context["type"]];
        context["pos"] += RSTART+RLENGTH-1;

    } else if (ch == "t" && substr(context["in"],context["pos"],4) == "true") {

        context["type"] = "boolean";
        context["value"] = context[context["type"]]  = 1;
        context["pos"] += 4;

    } else if (ch == "f" && substr(context["in"],context["pos"],5) == "false") {

        context["type"] = "boolean";
        context["value"] = context[context["type"]]  = 0;
        context["pos"] += 5;

    } else if (ch == "n" && substr(context["in"],context["pos"],4) == "null") {

        context["type"] = "string";
        context["value"] = context[context["type"]]  = "";
        context["pos"] += 4;

    } else {
        json_err(context,"Error parsing "context["tag"]);
    }
    if (ch != "{" && ch != "[" ) {
        #json_dbg(context,"scalar "context["type"]" = "context["value"]);
    }
}

function json_assign_value_to_tag(context,out) {
    if (context["err"] == "") {
        if (context["type"] != "array" && context["type"] != "object") {
            #json_dbg(context,"assign "context["tag"]"="context["type"]":"context["value"]"="context[context["type"]]);
            out[context["tag"]] = context[context["type"]];
        }
    }
}


function json_parse_array(context,out,\
idx) {
    delete context["type"];
    delete context["value"];

    if (context["err"] ) return;
    idx = 1;

    advance(context,"[");
    ltrim(context);
    if (currch(context) != "]" ){
        do {

            json_push_tag("#",idx++,context);
            if (context["err"] ) break;
            json_parse_value(context,out);
            if (context["err"] ) break;

            json_assign_value_to_tag(context,out);

            json_pop_tag(context);
            ltrim(context);

        } while (advance(context,",",1));
    }
    if (advance(context,"]")) {
        context["type"] = "array";
    } else {
        json_err(context,"list (,) or (])  expected ");
    }
}
function json_dbg(context,x) {
    if (context["dbg"])  print "INF:" x ;
}
