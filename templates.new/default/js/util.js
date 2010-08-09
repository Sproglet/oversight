// $Id:$
function ovs_nbsp() {
   return   " "; // nbsp - u00A0 in vim crtl-V u A0
}

function ovs_util_getcell(name) {
    var v = document.getElementById(name);
    if (v) {
        return v;
    } else {
        alert("missing page element "+name);
    }
}

function ovs_util_action(a,idlist,prompt_str) {
    var sep;
    if (idlist) {
        if (prompt_str=="" || !prompt_str || confirm(prompt_str)) {
            if (window.location.href.indexOf('?') == -1 ) {
                sep='?';
            } else {
                sep = '&';
            }

            location.replace(window.location.href + sep + "action="+a+"&actionids="+idlist);
        }
    }
}

function getPixelsFromTop(obj){
	var objFromTop = obj.offsetTop;
	while(obj.offsetParent!=null) {
		var objParent = obj.offsetParent;
		objFromTop += objParent.offsetTop;
		var obj = objParent;
	}
	return objFromTop;
}
