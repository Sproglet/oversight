The oversight cgi script is written in C which helps it run faster than similar awk or php based programs. This is important for dynamic pages on the NMT platform, which is relatively slow. Because it is written in C, it can do quite a lot of dynamic operations whilst drawing the HTML page.

Currently it renders a menu page to a PC browser in about 1 second for a database of about 500 files. TV/Gaya takes longer because the NMT is serving the page and drawing it.

## timing ##

At present, if you load oversight menu and do 'view source' the html comments start with two numbers..
cpu milli seconds / elapsed seconds.

The database is loaded between:
```
<!-- 166/0 Get rows -->
...
<!-- 498/0 First total 621 -->
<!-- 498/0 end db_scan_and_add_rowset 1 -->
```

Eg,

```
<!-- 166/0 Get rows -->
<!-- 166/0 query : EMPTY HASH -->
<!-- 498/0 Unknown field [_c] -->
<!-- 498/0 no genre [(null)][(null)] -->
<!-- 498/0 read_and_parse_row_ticks 290 -->
<!-- 498/0 inner_date_ticks 30 -->
<!-- 498/0 date_ticks 0 -->
<!-- 498/0 assign_ticks 0 -->
<!-- 498/0 filter_ticks 30 -->
<!-- 498/0 keep_ticks 10 -->
<!-- 498/0 discard_ticks 0 -->
<!-- 498/0 read_ticks 0 -->

<!-- 498/0 First total 621 -->
<!-- 498/0 end db_scan_and_add_rowset 1 -->
```

Here 621 items were scanned in 0.32s. This is the longest step of the page generation task. Once plots are moved out, I'm hoping this will drop below 0.2 seconds.

## time functions ##

There are some odd bits of code to tweak performance. For example rather than using the standard localtime()/mktime() functions to convert between struct tm and UNIX timestamps  I just pushed the time fields into different bits of a 'long long' variable.

http://code.google.com/p/oversight/source/browse/trunk/src/time.c

This reduced the cryptically named 'inner\_date\_ticks' figure from around 230 down to 30.