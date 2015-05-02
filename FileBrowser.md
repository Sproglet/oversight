# Oversight File Browser #

Oversight has a very basic file browser that gives a view only access to all files on the NMT. Not just those in the /share folder.

This is experimental, and in early stages at the moment, but it has some interesting uses
(especially for diagnosing problems - for users who are not familiar with telnet or netcat).

Basic file management functions may be added over time - eg sorting , deleting etc.

This will allow deletion of hidden files, navigation of symbolic links etc.

## Remotely check last watched program ##

The /tmp/0 file contains the last page displayed by the TV GUI. So you can use check this remotely using.

http://ip:8883/oversight/oversight.cgi?/tmp/0

## See all logs ##

http://ip:8883/oversight/oversight.cgi?/share/Apps/oversight/logs