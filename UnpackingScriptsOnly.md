#Installing unpacking scripts only

# Introduction #

This page descripbes how to install just the unpacking scripts. They do not have an installer, as they are sometimes used on other platforms. For NMT users it is much easier to just install Oversight and then dont use it. This will set up all of the optimal configurations for nzbget and the unpacking scripts. And Oversight uses VERY little resources if its not being used. It doesnt require myIHome etc.

For non-NMT users, or stubborn, frugal NMT users read on..


# Installation #

Download and unpak latest oversight. Keep the following files and delete the others,

The file heirachy should be

  * unpak.sh

  * conf/.unpak.cfg.defaults #defaults for all new settings
  * conf/unpak.cfg # your file - copy from unpak.cfg.example
  * conf/unpak.cfg.example #initial file for 1st time users

  * catalog.sh

  * conf/.catalog.cfg.defaults #defaults for all new settings
  * conf/catalog.cfg # your file - copy from unpak.cfg.example
  * conf/catalog.cfg.example #initial file for 1st time users

  * bin/plot.sh

Also for NMT platform L:

  * bin/jpeg\_fetch\_and\_scale - grabs posters and fanart.
  * bin/nmt100/ - contains libjpeg and gnu versions of some apps
  * bin/nmt200/ - contains libjpeg and gnu versions of some apps

These 'gnu' version of wget and gzip are slightly easier to work with than their busybox equivalents.

# Configuration #

In nzbget.conf then set the following options

```
PostProcess=/replace/with/path/to/unpak.sh
AllowReprocess=yes
ParCheck=no
ParRepair=no
RenameBroken=no
CreateBrokenLog=yes
```

Optionally, For better nzbget debugging and performance on NMT I also set the following
(all automatically set by installing oversight)

```
Detailtarget=none
Debugtarget=none
Infotarget=screen
Warningtarget=both
Errortarget=both
Createlog=yes
Resetlog=yes
LogBufferSize=100
#IO Performance
DirectWrite=yes
ContinuePartial=no
```


```
OutputMode=loggable <= only if your nmtclient doesnt have curses support - NMT users should set this 
NzbDirFileAge=12
DupeCheck=yes
```