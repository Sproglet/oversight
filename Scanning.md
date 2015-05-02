# Scanning #

## Full Scans ##

With Version 20091123-3beta upwards, Full Scans should now only be done when:

- Oversight is installed for the first time. (in which case 'new' scan does the same thing
- Oversight has been removed and re-installed. (ditto)
- Oversight upgrade instructions suggest a full rescan - this is often to change some internal data.
- You have quite a few false matches and have just upgraded Oversight, and want to see if it fixes them.
- A scan was affected by lost internet connectivity or site unavailability.

Before doing a rescan use the site checker link "{check internet databases}".
(See the FAQ for why 3 search engines are used)

## Incremental Scans ##

Oversight automatically launches incremental scans in three instances:

  1. On completion of a usenet download.
  1. When new content is added to 'watch folder'
  1. When a NMT Transmission Torrent is completed (this needs more testing)

I plan to have a rescan button against a particular item.
First we need an edit option to change IMDB Id., fanart & poster links.
Then "save" or "save and rescan"

In the mean time you can rescan a particular item as follows: (v20091123-3 or better)

  1. In the Oversight GUI, _delist_ the item to be rescanned (don't _delete_ it!!)
  1. Go to the Admin Screen, and select only the paths that contain your changed items, and select 'new items only'
  1. Rescan.

This method looks through all folders for files that are not in the index, so it may take 5 minutes or more.


---


For posterity, the old way of doing it (via telnet) still works, but is not needed any more:

  1. log in
  1. type 'cd /share/Apps/oversight'
  1. type './catalog.sh /path/to/new/media/folder'
  1. Or to rescan AND get new posters type './catalog.sh UPDATE\_POSTERS /path/to/new/media/folder'