# This is a script to delete files in sequence 
# because NMT delete causes the system to become unresponsive, files are deleted in a concurrent 
# background thread, but if an entire box set is deleted, then we still only want to delete a 
# single file at a time.
# On a normal PC non of this would be needed but for large media files on the NMT, deleting 
# 20 1G files can affect usability.

cmd=true

for f in "$@" ; do
    case "$f" in
        --rm) cmd="rm -f " ;;
        --rmfr) cmd="rm -fr " ;;
        --rmdir) cmd="rmdir " ;;
        *) $cmd -- "$f" ;;
    esac
done
