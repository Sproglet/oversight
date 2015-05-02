

# wget wrapper #

Normally when Gaya invokes a CGI script, the following steps occur:

  1. gaya starts wget
  1. wget connects to internal web server
  1. web server starts cgi process and gets output
  1. output is sent to wget.
  1. wget saves output in /tmp/0
  1. gaya reads html in /tmp/0 and renders it

this testing release masquerades as the 'wget' binary. If it sees the request is for an oversight page then it intercepts it and writes the results to /tmp/0. Otherwise it is passed through to the original wget. So the new sequence for oversight.cgi is is :


  1. gaya starts wget (but its really oversight in disguise)
  1. oversight checks URL ~ oversight.cgi
  1. write output to /tmp/0
  1. gaya reads html in /tmp/0 and renders it

This saves a full startup of wget , and the overhead of connecting to a web server.
For other normal pages there is an extra step where oversight must start the real wget binary, however this is negligible compared to all the other stuff going on , esp as Oversight is a compiled binary.

## Manually Disabling the wget masquerading function ##

Starting with [r756](https://code.google.com/p/oversight/source/detail?r=756). If you encounter errors with gaya that you think may be caused by wget masquerading, then you can disable it as follows:

rename or delete the file /share/Apps/oversight/conf/use.wget.wrapper and reboot.

## Automatically Disabling the wget masquerading function ##

Starting with [r756](https://code.google.com/p/oversight/source/detail?r=756). Oversight itself will also create a file
/share/Apps/oversight/conf/wget.wrapper.error
if it crashes during page rendering.
If this file exists and a reboot is performed, then the wget masquerading feature will be disabled.