As things are currently in beta - if something doesnt work as expected its quite possible its is a bug. Rather than spending hours tearing your hair out, send the log files to me :)

As the software matures hopefully this will happen less often.



# Scan Logs #

Send these you have problems with adding or updating content.

"Help me... help you. Help me, help you. " - follow all the steps mentioned.

If all the info requested is present then I am more likely to investigate.
If I have to first spend 10 minutes figuring out what the problem is, who its from and where to look in a big log file then I might not be so keen :)

To send scan logs:

  1. **Follow all of the steps indicated, otherwise I may not follow up the problem**
  1. (on the TV/NMT go to Setup/NMT Applications) and make sure SMB/Samba service is started.
  1. Assuming you have a windows PC go to the Run dialog (Start->Run) and enter  \\192.168.x.y where 192.168.x.y is the IP address of your NMT. ( You can also put this is the address bar of Windows Explorer - it will probably NOT work with 3rd party browsers)
  1. Browse to Apps\oversight\
  1. Right click on the logs folder and zip it (send to Compressed Folder/Winzip/7zip/Winrar etc - I recommend [7zip](http://www.7-zip.org/))
  1. Email the new compressed file to me. nmt at lordy dot org dot uk.
  1. In the email **mention one or two specific examples of the problem**. Eg. The file "star trek 2009.avi" is indexed as "Star Trek Series 20 episode 9" (just an example - that shouldn't really happen ;) ). **Dont skip this step** - log files without any particular problem file identified may get ignored.
  1. **If you have reported the problem in the Oversight Threads on NMT forums mention your forum name/handle and add a direct link to the post number (not page) in the email**.

If  you have already looked in the logs and have a good idea **what** is causing oversight to trip up you could even raise  [a new defect](http://code.google.com/p/oversight/issues/list) and attach the logs directly. To do this, You only need to work out 'what' is causing the trouble not 'why' :)
Eg if scanning always fails on a particular file name, then that information along with the filename and the logs is enough.

# GUI Logs #

Send these if odd things happen in the user interface using the PC browser.

Send 'gui' logs if you think files have scanned OK but you are getting odd things happen in the user interface.

To send GUI logs:

  1. **Follow all of the steps indicated, otherwise I may not follow up the problem**
  1. Open Oversight in the PC.
  1. Go back to the page that is causing problems.
  1. if using Internet Explorer or Firefox, In the browser menu,  select File->Save As-> Type: Web Page HTML Only
  1. email the page to me as an attachment  nmt AT lordy dot org Dot uk.
  1. **If you have reported the problem in the Oversight Threads on NMT forums mention your forum name/handle and add a direct link to the post number in the email.**

# TV Logs #

Send these if odd things happen only via the TV interface - not PC

To get the page that is sent to gaya/tv, you must

  1. **Follow all of the steps indicated, otherwise I may not follow up the problem**
  1. Then load the problem page again on the TV screen.
  1. On the PC go to OVersight->Setup->Diagnostics->{Last TV GUI Log}
  1. Save the page to a file and then email the file to me as an attachment  nmt AT lordy dot org Dot uk.
  1. **If you have reported the problem in the Oversight Threads on NMT forums mention your forum name/handle and add a direct link to the post number in the email**.

If the issue is with the play button on the remote you will also need to send the playlist also. This is the file /tmp/playlist.htm (you will need telnet to access this)

# Check Log #

Send this if you have scanning issues but you have no scan logs!

To send a check log :
  1. Go to the standard NMT File Browser
  1. Go to Apps -> oversight
  1. Press the Blue button on the remote
  1. Select oversight-install.html
  1. Select 'Check Install'
  1. Send the Apps/oversight/logs/check.log file.