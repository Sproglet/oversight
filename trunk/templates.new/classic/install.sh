#!/bin/sh
# This script is run during installation
# It can be used to remove any obsoleted files for
# the current skin

# Get script folder
skin_home=`(cd "${0%/*}" ; pwd)`

installed="$skin_home/.installed"

#----------------------------------------------------

# Add any custom install steps here - eg deleting old files during upgrade
# so oversight will use default files.
install_skin() {


    rm -fr "$skin_home/js"
    rm -fr "$skin_home/css/default.css"
    rm -fr "$skin_home/any/"{movie,tv,tv_css,tv_js_basic,tv_js_advanced,tv_js}.template

}

#--------------------------------------------------
if [ ! -e "$installed" ] ; then

    install_skin

    #touch "$installed"

fi

