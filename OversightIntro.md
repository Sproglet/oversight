Oversight is a video jukebox that runs on the [NMT](http://www.networkedmediatank.com/wiki/index.php/Main_Page) platform.

It is aimed at users that

  * regularly download content to their internal hard drive, and
  * want to quickly identify and access the most recently downloaded material.

See [ScreenShots](ScreenShots.md)

There are quite a few [jukeboxes](http://www.networkedmediatank.com/wiki/index.php/Jukebox_Comparison) for the NMT platform now. Selecting the right one can be challenging. Especially if you start with ones that are not suitable for your own usage patterns.

# Oversight Features #

  * No PC needed (unless you want to)
    * Runs entirely on NMT but...
    * PC Browser interface allows smooth interaction + keyboard input.
    * Remote play - Click on browser - starts playing on TV.

  * Fully Automatic for lazy people and non-techies
    * Automatic TV Boxset view.
    * Automatic Movie Boxset view. (Oversight uses sequel info from IMDB)
    * Automatic detection of unavailable NAS
    * PVR. Automatic addition of new media without any extra work.
    * NZBGet post-processing scripts. - Oversight installs a script that automatically adds new media to the Oversight Catalog. This script has many features.
    * Crossview: If you have OVersight installed on two NMT, then each can see the others media, all in a single Oversight session. No need to switch sources or jukeboxes.
    * Miminal File Renaming
    * Wide variety of file naming formats detected.
    * Scene names detected. No need to rename those downloads.
    * Localized movie name recognition - E.g. will scan movies with Russian file names.

  * Consolidated view
    * Auto-mounting built in - playback from multiple NAS( including ISOs)
    * All content from different sources displayed in a single view. (Some might consider this a weakness if they really want separate jukeboxes)

  * Dynamic
    * Mark shows as watched.
    * Delete files using gui.
    * Sort and filter views dynamically. Filters can be combined.. eg Unwatched Movies beginning with 'T', or Watched Tv Shows beginning with 'M'.
    * Automatically removes icons for files that have been manually deleted.

  * Plays nice
    * Read-Only - Does not write to media folders so can run along side other Jukeboxes.
    * Does not depend on MyIHome service nor internal apache webserver.
    * SD support.
    * PAL support.  The NMT Browser squashes images on PAL displays. Oversight compensates for this.
  * Multi-lingual support


# Oversight Weaknesses #

> Some reasons you may not want to use oversight right now

  * Page load speed - Because Oversight is dynamic It is no match for a jukebox built on static pages - but its still very usable giving you a real time view of your media.
  * No post scan tweaking of plots etc. - This will be implemented soon.

  * Detailed Scraping. Actor Bios, Names of Producers, Cleaners and all that kind of stuff is not supported. Via the PC, Oversight provides a link to IMDB.
  * Media attribute detection. Currently display of framerates etc is not supported.
  * TV Series in ISO Images not supported. (This is on the roadmap)
  * All media in one view - some people want to partition their media - for example have a Kids jukebox, or a 'Chick-Flick' jukebox. This is not supported right now.

> Some reasons you may not want to use oversight ever

  * Oversight needs NMT apps to be installed. If you dont want a big hard drive in your NMT then the 200 series Popcorns can run NMT apps from a USB stick, and maybe consider an old 4200 rpm laptop drive for a 100 series.

# Oversight Testing #

**Oversight is currently in beta. This means that there is a new version every couple of weeks. I make a best effort at testing but it has a lot of major feature sets (unpacking, deep web search/scrapes , dynamic gui, skins, auto-mounting, NMT sharing etc) and to run a comprehensive test suite would literally take hours. So my current practice is to sanity test, release the changes into the community rapidly, and they can feed back any issues.
At present this seems to be working ok, and allows me to spend more time coding than testing.**

I really really need to build a test suite!