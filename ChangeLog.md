# Oversight Change Log #

v2.0testing-[r2258](https://code.google.com/p/oversight/source/detail?r=2258)

  * Faster network resolving for IP addressed based mounts
  * Fixed failure to install on 100 series due to recent script environment changes

v2.0testing-[r2185](https://code.google.com/p/oversight/source/detail?r=2185)

v2.0testing-[r2006](https://code.google.com/p/oversight/source/detail?r=2006)


v2.0testing-rxxxx

  * gui: Grid Segment fixes
  * gui: Viewing 2nd page fixed when default filter in config, but overridden(cleared) in GUI ( [Issue 462](https://code.google.com/p/oversight/issues/detail?id=462))
  * gui: Simpler GRID and PAGE\_MAX macros - two passes of template.
  * gui: Changed admin screen layout
  * gui/scan: Set permissions in ./cache folder in admin screen
  * gui: Changed default skin to oversight

  * scan: Fetch images for watched content ([Issue 469](https://code.google.com/p/oversight/issues/detail?id=469))
  * scan: Scan IMDB id in file name ([Issue 459](https://code.google.com/p/oversight/issues/detail?id=459))
  * scan: Follow soft links option ([Issue 430](https://code.google.com/p/oversight/issues/detail?id=430))
  * scan: Scrape from m.imdb.com optional - may help when IMDB change main site.
  * scan: Parse roman numerals in mini-series notation.

  * gui/install: Cleaner template installation when upgrading

v2.0testing-[r1369](https://code.google.com/p/oversight/source/detail?r=1369)

  * Individual skin configuration

v2.0testing-[r1298](https://code.google.com/p/oversight/source/detail?r=1298)
  * Scan best rated images from http://themoviedb.org
  * Automatic Movie boxsets and boxset icons. (using IMDB follows/followed by)
  * Actor/Writer/Director scraping
  * File locking
  * IMDB Rating filter
  * Better skin support.
  * Faster page loading
  * Follow symlink option.
  * Remote File system browsing ( http://ip:8883/oversight/oversight.cgi?/path/to/file )
  * Many bug fixes.

v1.0
  * Patched rc9 with missing files

[r1186](https://code.google.com/p/oversight/source/detail?r=1186)-rc9

  * Fix: Runtime scanning
  * Enhancement: unpak rar extensions s00,s01.. (untested - naughty I know)
  * Fix: Gui - allow drill down on items without posters.

[r1120](https://code.google.com/p/oversight/source/detail?r=1120)-rc8
  * ignore underscore when extracting tv name details. (affected regex word boundaries)

[r1104](https://code.google.com/p/oversight/source/detail?r=1104)-rc7
  * delete navigation fixes where Tv and Movie have same title.

[r1090](https://code.google.com/p/oversight/source/detail?r=1090)-rc6
  * Fixes: More delete navigation fixes.
  * Features: Very slight menu speedup.

[r1048](https://code.google.com/p/oversight/source/detail?r=1048)-rc5
  * Fixes: Interim fix for movie deletion

[r1044](https://code.google.com/p/oversight/source/detail?r=1044)-rc4
  * Fixes: > 12 series view on tvboxset

[r1030](https://code.google.com/p/oversight/source/detail?r=1030)-rc3
  * Fixes : uptime error finding load avg.

[r1021](https://code.google.com/p/oversight/source/detail?r=1021)-rc1
  * disabled [PLAY](PLAY.md) on dvd - use [OK](OK.md)
  * body\_height change
  * remote access fix
  * in js fix
  * Other category

[r1004](https://code.google.com/p/oversight/source/detail?r=1004)-testing
  * Comsetic: favicon / replace 720 with HD on admin view

[r1001](https://code.google.com/p/oversight/source/detail?r=1001)-testing
  * Handling of punctuation in tv names

[r997](https://code.google.com/p/oversight/source/detail?r=997)-testing
  * better YEAR macro / remove dot from titles

[r994](https://code.google.com/p/oversight/source/detail?r=994)-testing
  * Delete Navigation
  * Scan Shows with period.
  * Reboot Fix
  * Remove setsid scan message.
  * Probe nfs port before portmapper.
  * Probe SMB port 139 as well as 445.
  * Includes Skins
  * Bookmark Icon

[r925](https://code.google.com/p/oversight/source/detail?r=925)-testing
  * CSI tweaks.
  * Allow Custom posters for unidentified media

[r920](https://code.google.com/p/oversight/source/detail?r=920)-testing
  * Hyphen in titles

[r917](https://code.google.com/p/oversight/source/detail?r=917)-testing
  * Various Scanner fixes.
  * Faster index loading.
  * Sort by file age or index time.

[r890](https://code.google.com/p/oversight/source/detail?r=890)-testing
  * nfo for video\_ts
  * multipart fix
  * gawk compatibility fixes
  * tvrage id extraction / normailse fixes

[r863](https://code.google.com/p/oversight/source/detail?r=863)-testing
  * unpak.sh more robust deleting and moving

[r861](https://code.google.com/p/oversight/source/detail?r=861)-testing
  * Better parsing of IMDB aka titles.
  * Replace bbawk with gawk

[r853](https://code.google.com/p/oversight/source/detail?r=853)-testing
  * Genre-o bug - bundled busybox from CSI

[r851](https://code.google.com/p/oversight/source/detail?r=851)-testing
Fixes:
  * Genre-o workaround. (tx Sproglet)
  * 00x00 fix.
  * Ignore dates when looking for title year.
  * English title selection for Good Bad Ugly, Two Brothers etc.
  * Delete of last entry on detail page returns to parent menu
  * bdmv support (tx Nicob)

[r830](https://code.google.com/p/oversight/source/detail?r=830)-testing
Fixes:
- date/age
- imdb AKA titles
- parse e01-e02 s02-e03
- Fix awk memory exhuasted when parsing compacted HTML
- Matching TV titles with year.
Features:
- scanner changes (look for title then id)
- reset DNS cache
- Seperate Delete/Delist
Other:
- force nzbget to run as nmt (seems to be an issue with latest A200 apps)

[r803](https://code.google.com/p/oversight/source/detail?r=803)-testing

Fix to mis-identification of episodes >= 10 (busybox awk buggette 1333)
Scanner refinements.
To do a rescan, delist(not delete!) the dodgy items, and then rescan.

[r797](https://code.google.com/p/oversight/source/detail?r=797)-testing

utf8 support for Léon etc.
improved wget wrapper
improved scanning
optional movie file name in detail screen
diagnostics page.

[r761](https://code.google.com/p/oversight/source/detail?r=761)-testing

fixes to auto-mounting - handles shares with spaces , no duplicate mounting.

[r756](https://code.google.com/p/oversight/source/detail?r=756)-testing

Fixed local poster and fanart for video\_ts
Limit size of SMB scan network to /21
Disable wget masquerading at reboot if:
- user manually renamed or deleted conf/use.wget.wrapper .
- or oversight was abruptly terminated (conf/wget.wrapper.error)

[r749](https://code.google.com/p/oversight/source/detail?r=749)-testing

Restored skin option on settings page.

[r746](https://code.google.com/p/oversight/source/detail?r=746)-testing

Faster page load (ok not a bug fix but it did bug me for a long while)
nfs-tcp support.
Fixed certificate image links.
Restored File name in Movie detail.

[r738](https://code.google.com/p/oversight/source/detail?r=738)-testing

Added missing country.txt file.

[r734](https://code.google.com/p/oversight/source/detail?r=734)-testing

  * Installer uses /proc/cpuinfo to determine platform (gave up on egreat version numbering)

[r727](https://code.google.com/p/oversight/source/detail?r=727)-testing

  * Fixed parsing of NAS timeout
  * changes for new IMDB certificate links.
  * Fixed delete image option.
  * Share Host ip lookup ignores routable ips (to ignore OpenDNS fake ip response)
  * nbtscan updates stale conf/wins.txt (rather than waiting for catalog script)
  * Fix Egreat M32 and Kaiber install - Firmware class -405 (B110 board) added to installer.
  * Dont ignore all paths if ignore path setting is blank.
  * Fixed parsing of empty settings.
  * Fixed malloc error with empty Genre.

[r707](https://code.google.com/p/oversight/source/detail?r=707)-testing
  * Fix to C200 1080p mode.
  * Unpak status fix (revisited)
  * IE drilldown fix (IE CSS bug. surprise)
  * Fix to Crossview Delete function.

[r698](https://code.google.com/p/oversight/source/detail?r=698)-testing
  * Fix to IMDB Year Scanning.
  * Remove searches in BinTube (not free anymore)
  * Hopefully scripts will work with A200

[r667](https://code.google.com/p/oversight/source/detail?r=667)-testing
  * Fix to NAS incremental scans

[r665](https://code.google.com/p/oversight/source/detail?r=665)-testing
Fix to hex dates - needs a full rescan if upgrading from 662.
  * Some scanning improvements - eg "2x13 episode title.avi" can be scanned without the series name. (except '1x01 Pilot.avi' will give problems )

[r662](https://code.google.com/p/oversight/source/detail?r=662)-testing
  * Fix to blank page after scan - WINS resolving for samba shares.

20090903-1BETA

  * Filter by Genre
  * Simple Alphabet Filter (removed TVID filter)
  * Dynamic display of video title as you navigate.
  * Some Scanning improvements.
  * Alternate template layouts fanart vs no-fanart.
  * 1080p treated as 720p (should look decent to people running on 1080p)
  * Deleted files are pruned. - They are first highlighted as removed in the GUI, then the message goes away.
  * Some Gui performance tweaks.
  * Bugfixes.

20090814-1BETA

  * templates offer basic "skinning" capability
  * Automatically Watch Folders for new content. (including NAS)
  * Auto-mount and playback from multiple NAS (avi,mkv AND ISOs)
For auto-NAS mounting you must change the scan path to simply be the share name.. eg.
/share/Video,/share/Movies,NAS1,NAS2/films
The full unix path is no longer required and should not be used.
  * Fanart / Backdrops. - Can be turned off too for purists Smile
  * Remote Play - Click on your browser - starts playing on the TV.
  * Re-write in C. Mark/Remove operations are much faster and also made dynamic/on-the-fly skinning possible.


20090721-1BETA
  * Better Abbreviation detection 'law and order svu' 'fguy' grk' 'desperateh' 'ttscc'
  * bundled gzip binary for non-telnet HDX/eGreat
  * Better info displayed for "daily" shows.
  * Display tvmode code in setup screen.
  * Search tvdbcom for 'and' or '&'
  * remove redundant epguides code.
  * Fixed Donate button removal - God knows why! :)
  * Fixed Duplicate Movies during incremental scanning (due to memory usage fix)
  * avoid tv match for hd1080
  * Work around for Gaya PAL a/r bug.

20090719-1BETA

  * Fixed unzipping on HDX/eGreat that do not have telnet installed.
  * Better Memory Usage
  * Simple NAS/USB support - files are not de-listed if grandparent folder missing

20090717-1BETA

  * Fixed case of titles. [Issue 11](http://code.google.com/p/oversight/issues/detail?id=11&can=7)
  * Fixed file deletions [Issue 1](http://code.google.com/p/oversight/issues/detail?id=1&can=7)
  * unpak: fixed error with original nzbget 0.5.1 [Issue 10](http://code.google.com/p/oversight/issues/detail?id=10&can=7)
  * catalog: Made sure folders/files are removed from index if they may ignore patterns. [Issue 2](http://code.google.com/p/oversight/issues/detail?id=2&can=7)

20090707-2BETA

  * Fix typo in catalog.sh

20090605-2BETA

  * Minor bug fix to tvscanning when mapping imdbid to tvdbid

20090706-1BETA
> unpak      Fix reference to NZBOP\_APPBIN for older nzbget

20090605-1BETA

  * oversight (gui)
    * Border on posters of new content
  * catalog (scanner)
    * Fix bug for YAMJ multi-part naming convention
    * Display scan progress.
    * Get Season Posters and episode information from thetvdb.com then imdb
    * Get Movie Posters from themoviedb.com / motechposters.com / imdb
    * Search for imdblinks in online usenet nfo files.
    * Removed deep search - not accurate enough
    * Abbreviation Detection - eg ttscc , Grk , dh501 combined with usenet file search.
    * Parsing and grouping of Big Brother UK format
    * Better Grouping of Daily Shows and Unknown shows
    * Can use locally stored posters.

Known Issues :    Sample Deletions not working for some.
> Reduce false positives further.
20090314-1BETA

  * unpak
    * Fix to delete sample files.
  * catalog
    * Fix for quoted files. Should solve some scanning issues people are having.
    * Fix multipart detection. CD01
    * Detect when Epguides links to pilot episode on IMDB rather than series e.g "Ugly Betty".

20090507-1BETA
  * catalog
    * Fix for short imdb ids (5 digit eg Simpsons)

20090507-1BETA
Mar05: oversight: Added Poster View

20090507-1BETA
  * oversight
    * Update tool / unrolled db read loop
  * unpak
    * cross platform fix to awk regex

20090307-1BETA
  * catalog
    * Split file detection fixed.
  * unpak
    * Cross platform unpak fixes. Another path bug fixed.

20090307-1BETA
Apr30: catalog  : Better matching C.S.I to CSI ,aaf-sp.s13e07
> unpak:Removed &quot;which&quot; command