# Parse a json structure into awk array
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

# IN json string.
# OUT array.
function json_parse(in,out,\
context) {
    delete out;
    context["tag"] = "";
    json_parse_object(in,context,out);
    dump(0,"json",out);
}

function json_err(in,context,msg) {
    context["err"] = context["err"] msg;
    ERR("json: "msg" parsing ["in"]");
}

function json_next_token(in,ch) {
    return match(in,"[ \t]*"ch);
}

function ltrim(in) {
    sub(/^[ \t]+/,"",in);
    return in;
}

function json_parse_string(in,context,\
i) {

    context["string"] = "";

    in = ltrim(in);

    if (substr(in,1,1) != "\"" ) {
        json_err(in,context,"Expected \"");
    } else {
        for(i = 2 ; i <= length(in) ; i++ ) {


            if (substr(in,i,1) == "\\") {

                # if escaped then skip next
                i++;

            } else if (substr(in,i,1) == "\"") {

                # if quote then end
                context["type"] = "string";
                context[context["type"]] = substr(in,2,i-2);
                in = substr(in,i+1);
                break;
            }

        }
    }

    return in;
}

function json_push_tag(tag,context) {
    context["tag"]= context["tag"]":"tag;
}

function json_pop_tag(context) {
    sub(":[^:]+$","",context["tag"]);
}

# IN json string.
# IN/OUT array.
# Return remaining string

function json_parse_object(in,context,out,\
label) {

    if (context["err"] ) return in;

    if (!json_next_token(in,"{")) {
       json_err(in,context,"{ expected");
    } else {
        in = substr(in,RSTART+RLENGTH);

        while(1) {

            in = ltrim(in);

            if (substr(in,1,1) != "\"") break;
            
            in = json_parse_string(in,context);
            if (context["err"]) break;

            label = context["string"];

            in = ltrim(in);

            if (substr(in,1,1) == ":")) {

                in = ltrim(substr(in,2));

                json_push_tag(label,context);

                in = json_parse_value(in,context,out);
                json_assign_value_to_tag(context,out);
                
                if (context["err"]) break;

                # Remove last tag
                json_pop_tag(context);

                in = ltrim(in);

                # check for comma
                if (substr(in,1,1) != ",") {
                    break;
                }
                in = substr(in,RSTART+RLENGTH);

            } else {
                json_err(in,context,": expected");
                break;
            }
        }
        if (substr(in,1,1) != "}" ) {
            json_err(in,context,"} or string expected");
            break;
        } else {
            context["type"] = "object";
        }

    }
    return in;
}

function json_parse_value(in,context,out) {

    in = ltrim(in);

    delete context["type"];
    delete context["value"];

    if (substr(in,1,1) == "[" ) {

        in = json_parse_array(in,context,out);

    } else if (substr(in,1,1) == "{" ) {

        in = json_parse_object(in,context,out);

    } else if (substr(in,1,1) == "\"" ) {

        # string

        in = json_parse_string(in,context,out);
        if (context["err"]) break;
        context["value"] = context[context["type"]];

    } else if (match(in,"^[0-9.eE]+") ) {

        # number
        context["type"] = "number";
        context["value"] = context[context["type"]]  = 0+substr(in,RSTART,RLENGTH);
        in = substr(in,RSTART+RLENGTH);


    } else if (in ~ /^(true|false)\>/ ) {

        context["type"] = "boolean";
        context["value"] = context[context["type"]]  = (index(in,"true") == 1);
        in = substr(in,RSTART+RLENGTH);

    } else {
        json_err(in,context,"Error parsing "context["tag"]);
        break;
    }
    return in;
}

function json_assign_value_to_tag(context,out) {
    if (context["err"] == "") {
        if (context["type"] != "array" && context["type"] != "object") {
            out[context["tag"]] = context[context["type"]];
        }
    }
}

function json_parse_array(in,context,out,\
idx) {
    delete context["type"];
    delete context["value"];

    if (context["err"] ) return in;
    in = ltrim(in);
    idx = 1;

    if (substr(in,1,1) != "[" ) {
        json_err(in,context,"Expected \"");
    } else {
        do {
            in = ltrim(substr(in,2));

            json_push_tag(idx++,context);
            in = json_parse_value(in,context,out);
            if (context["err"] ) break;

            json_assign_value_to_tag(context,out);

            json_pop_tag(context);
            in = ltrim(in);

        } while(substr(in,1,1) == ",");
        if (substr(in,1,1) != "]" ) {
            json_err(in,context,", or ] expected");
        } else {
            context["type"] = "array";
        }
    }
    return in;
}
