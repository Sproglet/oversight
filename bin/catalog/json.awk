# real json content from url into array.
function fetch_json(url,label,out,\
f,line,ret,json) {
    f=getUrl(url,label,1);
    if (f) { 
        FS="\n";
        while(enc_getline(f,line) > 0) {
            ret = 1;
            json = json " " line[1];
        }
        enc_close(f);
        json_parse(json,out);
    }
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
    context["dbg"] = 0;
    json_parse_object(input,context,out);
}

function json_err(input,context,msg) {
    context["err"] = context["err"] msg;
    ERR("json:"msg" parsing ["input"]");
}

function json_next_token(input,ch) {
    return match(input,"[ \t]*"ch);
}

function ltrim(input) {
    if (index(" \t",substr(input,1,1))) {
        sub(/^[ \t]+/,"",input);
    }
    return input;
}

function json_parse_string(input,context,\
i) {

    context["string"] = "";

    input = ltrim(input);

    if (substr(input,1,1) != "\"" ) {
        json_err(input,context,"Expected \"");
    } else {
        for(i = 2 ; i <= length(input) ; i++ ) {


            if (substr(input,i,1) == "\\") {

                # if escaped then skip next
                i++;

            } else if (substr(input,i,1) == "\"") {

                # if quote then end
                context["type"] = "string";
                context[context["type"]] = substr(input,2,i-2);
                input = substr(input,i+1);
                break;
            }

        }
    }

    return input;
}

function json_push_tag(prefix,tag,context) {
    if (context["tag"]) {
        context["tag"]= context["tag"] prefix tag;
    } else {
        context["tag"]= tag;
    }
}

function json_pop_tag(context) {
    sub("(^|[:#])[^:#]+$","",context["tag"]);
}

# IN json string.
# IN/OUT array.
# Return remaining string

function json_parse_object(input,context,out,\
label) {

    if (context["err"] ) return input;

    input = ltrim(input);

    if (substr(input,1,1) != "{") {
       json_err(input,context,"{ expected");
    } else {
        input = substr(input,2);

        while(1) {

            input = ltrim(input);

            if (substr(input,1,1) != "\"") break;
            
            input = json_parse_string(input,context);
            if (context["err"]) break;

            label = context["string"];
            json_dbg(context,"name="label" rest="input);

            input = ltrim(input);

            if (substr(input,1,1) == ":") {

                input = substr(input,2);

                json_push_tag(":",label,context);

                json_dbg(context,"begin parse value ["input"]");
                input = json_parse_value(input,context,out);
                json_dbg(context,"end parse value ["input"]");
                json_assign_value_to_tag(context,out);
                
                if (context["err"]) break;

                # Remove last tag
                json_pop_tag(context);

                input = ltrim(input);

                # check for comma
                if (substr(input,1,1) != ",") {
                    break;
                }
                input = substr(input,2);

            } else {
                json_err(input,context,": expected");
                break;
            }
        }
        if (substr(input,1,1) != "}" ) {
            json_err(input,context,"} or string expected");
        } else {
            context["type"] = "object";
            input = substr(input,2);
        }

    }
    return input;
}

function json_parse_value(input,context,out) {

    input = ltrim(input);

    delete context["type"];
    delete context["value"];

    if (substr(input,1,1) == "[" ) {

        input = json_parse_array(input,context,out);

    } else if (substr(input,1,1) == "{" ) {

        input = json_parse_object(input,context,out);

    } else if (substr(input,1,1) == "\"" ) {

        # string

        input = json_parse_string(input,context);
        if (context["err"]) break;
        context["value"] = context[context["type"]];

    } else if (match(input,"^[0-9.eE]+") ) {

        # number
        context["type"] = "number";
        context["value"] = context[context["type"]]  = 0+substr(input,RSTART,RLENGTH);
        input = substr(input,RSTART+RLENGTH);

    } else if (substr(input,1,4) == "true") {

        context["type"] = "boolean";
        context["value"] = context[context["type"]]  = 1;
        input = substr(input,5);

    } else if (substr(input,1,5) == "false") {

        context["type"] = "boolean";
        context["value"] = context[context["type"]]  = 0;
        input = substr(input,6);

    } else {
        json_err(input,context,"Error parsing "context["tag"]);
    }
    if (context["type"] ~ "string|number|boolean" ) {
        json_dbg(context,"scalar "context["type"]" = "context["value"]" : rest = "input);
    }
    return input;
}

function json_assign_value_to_tag(context,out) {
    if (context["err"] == "") {
        if (context["type"] != "array" && context["type"] != "object") {
            json_dbg(context,"assign "context["tag"]"="context["type"]":"context["value"]"="context[context["type"]]);
            out[context["tag"]] = context[context["type"]];
        }
    }
}

function json_parse_array(input,context,out,\
idx) {
    delete context["type"];
    delete context["value"];

    if (context["err"] ) return input;
    input = ltrim(input);
    idx = 1;

    if (substr(input,1,1) != "[" ) {
        json_err(input,context,"Expected \"");
    } else {
        do {
            input = ltrim(substr(input,2));

            json_push_tag("#",idx++,context);
            input = json_parse_value(input,context,out);
            if (context["err"] ) break;

            json_assign_value_to_tag(context,out);

            json_pop_tag(context);
            input = ltrim(input);

        } while(substr(input,1,1) == ",");
        if (substr(input,1,1) != "]" ) {
            json_err(input,context,", or ] expected");
        } else {
            context["type"] = "array";
        input = substr(input,2);
        }
    }
    return input;
}
function json_dbg(context,x) {
    if (context["dbg"])  print "INF:" x ;
}
