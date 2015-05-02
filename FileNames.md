An overriding requirement of Oversight is to minimize manual file renaming.
For information on changing NZBGet download locations see [NZBGetIntegrationAndRenaming](NZBGetIntegrationAndRenaming.md)



Most non-alphanumeric characters are ignored when trying to guess what film or tv show is in a file.

Oversight is optimized for scene release names. So in most cases files downloaded should not be renamed. However it can also attempt to lookup names using the Show or Film title.

# Movie Names (avi,mkv,iso etc) #

Scene release name (ie the download name) are best if the download was made available within the last 2 years on usenet.

After that the film title or title and year.

The file name is sanitized and then Oversight searches the internet for the most frequently occuring imdb reference that occurs with the title. (Note Imdb itself is NOT searched , as a single hit on IMDB will overwhelm all other results). This generally works well , except for remakes.
Separators can usually be any non-alphanumeric characters.


Eg.
scr-tw.iso
The Wrestler 2008.iso
The Wrestler - 2008.iso
The Wrestler (2008).iso

You can also put the imdbid in a nfo file in the same folder. In this case it would be tt1125849.

Note on occasion two scene releases will have the same name eg..
scr-tw.iso actually matches both The Wrestler and The Walker. In this case, at present it will chose the one with the most occurences.

# TV Shows #

TV Shows should have the title followed by the season and episode.

Separators can usually be any non-alphanumeric characters.
eg.

Lost.S05e05.avi
Lost.S05e05.720p.hdtv.avi

## Abbreviations ##

In order to support scene names, if there is not direct match at thetvdb.com., various abbreviations are also searched, as this is quite common.  In this case, for this to work, the Tv Program also needs to be listed on epguides.com. This is pretty much guesswork from Oversights perspective but it seems to do a good job, for stuff I watch. As more than one show may match an abbreviation, Oversight discards ones that do not have the "Overview" and "FirstAired" information defined at thetvdb.com.

Anything between the eipsode text and the extension is stored as additional information, and is displayed if Oversight cannot find the episode title at thetvdb.com.


Best format is the Show Name (as per thetvdb.com )

# NFO Files #

when Oversight cannot correctly recognise a file, you can help it along by creating an NFO file. This file should
  * contain the IMDB id of the movie or TV show. For example for the film Predator the file must contain the text 'tt0093773'.
  * have the same filename as the main movie but with a different extension. eg if you have Predator in a file called 'Predator 720p.avi' then the nfo file should be called 'Predator 720p.nfo'

After creating the nfo file 'De-list' the item and then rescan.
[More info on delisting](IncrementalScans.md)

# Images #

The scanning process downloads its own posters and fanrt to an internal folder, however you can use you own posters if you put them in the same folder as the media, and then re-scan.


## Posters ##

[Starting with r1977, to imporve page load performance, external images are processed by the scanner, so you must delist and rescan to see custom posters. (or reset the Oversight database and rescan). ](.md)

At present Posters should either
  1. Just be called poster.jpg or poster.png OR
  1. have the same name as the file but the .jpg or .png extension .e.g.

```
The-Wrestler.avi

The-Wrestler.jpg
or
poster.jpg
```

and for DVD structures ...

```
The-Wrestler/VIDEO_TS

The-Wrestler/The-Wrestler.jpg
or
The-Wrestler/poster.jpg
```



The image size does not really matter as it is scaled to fit.
The aspect ratio is approximately (1.5 x 1 eg 300x200 , 1500x1000 etc)

I would go for 450 x 300

Eventually (not yet!) there will be a much looser assciation. If there is only one film in a folder then Oversight will assume any portrait image is the poster. (unless it has the word "fanart" in it's name)

## Fanart ##

[Starting with r1977, to imporve page load performance, external images are processed by the scanner, so you must delist and rescan to see custom posters. (or reset the Oversight database and rescan). ](.md)

At present Fanart should either
  1. Just be called fanart.jpg or fanart.png OR
  1. have the same name as the file but the .fanart.jpg or .fanart.png extension. eg

```
The-Wrestler.avi

The-Wrestler.fanart.jpg
or
fanart.jpg
```

and for DVD structures...

```
The-Wrestler/VIDEO_TS

The-Wrestler/The-Wrestler.fanart.jpg
or
The-Wrestler/fanart.jpg
```

The image sizes are :

| Video mode | Resolution |
|:-----------|:-----------|
| SD NTSC | 685 x 460 |
| SD PAL | 685 x 542 (note this will appear stretched in a normal image viewer, but this will compensate for a bug in the GAYA viewer) |
| HD 720/1080 | 1280 x 720 |


Again this may change to automatically chose any landscape image in the same folder.

# ISO TV Shows #

There is no support for ISO TV SHows. yet.
For Movie Isos, Posters, Fanart and NFO should be in the same folder that **contains** the VIDEO\_TS folder. (ie they should be neighbours)