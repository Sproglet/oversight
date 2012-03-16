#!/bin/sh
# $3 =
# Following envs are exported
# $OVS_ID , $OVS_FILE, $OVS_NAME etc.

# see http://code.google.com/p/oversight/source/browse/trunk/bin/catalog/db.awk 

echo "custom script for new content"
env | grep OVS_ | sort
