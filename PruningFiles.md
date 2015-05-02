

# Pruning #

Oversight automatically removes deleted files from its database.

However Oversight will only prune files if their Grand Parent folder is present. This is to help ensure files are not pruned just because the NAS or USB device on which they reside is disconnected. It's not perfect but should work for most cases, and is simpler than trying to interrogate the mount table , esp if files are indexed via symlinks.