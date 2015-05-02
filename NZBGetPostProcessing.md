# NZBGet Post Processing #

Oversight installs a comprehensive nzbget post processing script:

This script has two parts:

  1. unpak.sh - does par repair and unpacking.
  1. catalog.sh - tries to identify TV and Movie downloads.

The post processing workflow is as follows:

  1. nzbget downloads the file in /share/Downloads
  1. unpak.sh, unpacks the file and will do a par-repair if that fails.
  1. unpak.sh then moves **all** completed files to /share/Complete (movies, tv, games, etc)
  1. If you do specified an nzbget category when uploading the nzb file, then it is moved to /share/Complete/category and post-processing stops.
  1. If you did not specify a category, then unpak.sh will check to see if the newsgroups in the nzb file contain any flagged words and if so move the file to the configured location and post processing will stop. (eg "erotica", and "sounds" are configured by default )
  1. At this stage post processing will hand over to the catalog.sh script which will try to identify the file as a TV Show or a Movie.
  1. If identified catalog.sh will then move it to the Tv or Movie location as configured in Oversight->Setup->Renaming