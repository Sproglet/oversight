

[Auto-generated at Fri May 11 00:59:45 BST 2012 from comments in macro.c using macro\_doc in trunk/src]

Oversight skins are html with special macros that are replaced with html text on the fly.

The macros are detailed below.
If this page becomes out of date, refer to macro.c
> ## BACKGROUND\_IMAGE ##
> BACKGROUND\_IMAGE(image name) - deprecated - use BACKGROUND\_URL()
> Display image from skin/720 or skin/sd folder. Also see BACKGROUND\_URL,FANART\_URL
> ## BACKGROUND\_URL ##
> BACKGROUND\_URL(image name)
> Display image from skin/720 or skin/sd folder. Also see FANART\_URL

## BANNER\_URL ##

THUMB\_URL(default\_image)
THUMB\_URL(default=>image,index=>nn)
Display  banner image for db item. If not present then look in the Oversight db, otherwise
use the named image from skin/720 or skin/sd folder. Also see BACKGROUND\_URL FANART\_URL POSTER\_URL THUMB\_URL

> ## CONFIG\_LINK ##
> > Description:
> > Generate text to link to a settings configuration form for a config file.

> Syntax:
`   [:CONFIG_LINK(conf=>,help=>,text=>link text,attr=>html_attributes,skin=1):] `
> Example:
## DETAILS\_URL ##

Generate a URL to drill down to this item.
` [:DETAILS_URL(index=>item_no):] `

If position is supplied this is preserved as query value i=
This allows a back button to return the the selected item on the grid.
` [:DETAILS_URL(index=>item_no,position=>pos):] `

## DUMP\_VARS ##

Dump all variables with the given prefix
## EDIT\_CONFIG ##

Write a html input table for a configuration file.
The config file is expected to have format
name=value

The help file has format
name:help text
OR
name:help text|val1|val2|...|valn

At present it calls an external file "options.sh" to generate the HTML table.
This script was kept from the original awk version of oversight as performance is not an issue
It may get ported to native code one day.

` [:EDIT_CONFIG:] `
` [:EDIT_CONFIG(conf=>name of config file,help=>help file suffix):] `

Default path for conf and help files is oversight/{conf,help}
if file = skin.cfg folder is the oversight/templates/skin/{conf,help}

## ELSE ##
` see multiline [IF] `
## ELSEIF ##
` see multiline [IF] `
## ENDIF ##
` see multiline [IF] `
## EVAL ##
Compute a value and insert into html output
Example:
`    td { width:[:EVAL($@poster_menu_img_width-2):]px; } `

## EXTERNAL\_URL ##

Display a link to movie or tv website (default website IMDB)

` [:EXTERNAL_URL:] `
` [:EXTERNAL_URL:(domain=>domain_name):]  `

Example:
` [:EXTERNAL_URL:(domain=>imdb):]  `
` [:EXTERNAL_URL:(domain=>themoviedb):]  `

## FANART\_URL ##

FANART\_URL(default\_image)
FANART\_URL(default=>image,index=>nn)
Display image  by looking for fanart for the first db item. If not present then look in the fanart db, otherwise
use the named image from skin/720 or skin/sd folder. Also see BACKGROUND\_URL BANNER\_URL POSTER\_URL THUMB\_URL

> ## FAVICON ##

> Display favicon html link.
`   [:FAVICON:] `
## FILE\_ENCODED(n) ##
Return url encoded name of n'th file part. See also FILEPARTS, FILE\_PATH FILE\_VOD\_ATTRIBUTES
=endwiki
/
char **macro\_fn\_file\_enc(MacroCallInfo**call\_info)
{
> > return macro\_fn\_file\_general(call\_info,FILE\_ENC);
}
/
## FILE\_NUM\_PARTS ##
Return number of parts  for a movie

IT should only be called on a movie detail page
## FILE\_PATH(n) ##
Return name of n'th file part. See also FILEPARTS, FILE\_ENCODED FILE\_VOD\_ATTRIBUTES
=endwiki
/
char **macro\_fn\_file\_path(MacroCallInfo**call\_info)
{

> return macro\_fn\_file\_general(call\_info,FILE\_PATH);
}
/
## FILE\_VOD\_ATTRIBUTES(n) ##
Return VOD attributes for n'th file part. See also FILEPARTS, FILE\_ENCODED FILE\_PATH
=endwiki
/
char **macro\_fn\_file\_vod(MacroCallInfo**call\_info)
{
> return macro\_fn\_file\_general(call\_info,FILE\_VOD);
}
/
## FLUSH ##

` Flush macro output. For debugging. [:FLUSH:] `
## FONT\_SIZE ##
Compute font\_size relative to user configured font size.
Examples:
```
    .eptitle { font-size:100% ; font-weight:normal; font-size:[:FONT_SIZE(-2):]; }
    td { font-size:[:FONT_SIZE:]; font-family:"arial"; color:white; }
```
## GRID ##
Grid Macro has format
` [:GRID(rows=>r,cols=>c,img_height=>300,img_width=>200,offset=>0):] `

All parameters are optional.
rows,cols            = row and columns of thumb images in the grid (defaults to config file settings for that view)
img\_height,img\_width = thumb image dimensions ( defaults to config file settings for that view)
offset               = This setting is to allow multiple grids on the same page. eg.
for a layout where X represents a thumb you may have:

```
XXXX
XX
```

This could be two grids
` [:GRID(rows=>1,cols=>4,offset=>0):] `
` [:GRID(rows=>2,cols=>2,offset=>4):] `

In this secnario oversight also needs to know which is the last grid on the page, so it can add the page navigation to
the correct grid. As the elements may occur in
any order in the template, this would either require two passes of the template, or the user to indicate the
last grid. I took the easy option , so the user must spacify the total thumbs on the page.

` [:GRID(rows=>1,cols=>4,offset=>0):] `
` [:GRID(rows=>2,cols=>2,offset=>4,last=>1):] `
## GRID ##

Display poster for current item.

` [:GRID:] `
` [:GRID(rows,cols,img_height,img_width,offset,order):] `

offset = number of first item in this grid segment. ITem numbering starts from 0.
if no offset supplied then it is computed from the size of the previous GRID.
This works as long as the grids appear in order within the HTML

orientation=horizontal, vertical :  determines sort order within the grid.

Example:

` [:SET(_grid_size,7):] `
` [:GRID(rows=>1,cols=>4,offset=>0,order=Horizontal):] `
` [:GRID(rows=>3,cols=>1,offset=>4,order=Vertical):] `

At present GRID cannot be inside a loop as they must be parsed during first pass.
> ## HELP\_BUTTON ##
> > Description:
> > Display a template image from current skins images folder - if not present look in defaults.

> Syntax:
`   [:HELP_BUTTON:] `
> Example:
`   [:HELP_BUTTON:] `
## IF ##
Multi line form:

` [:IF(exp):] `
` [:ELSE:] `
` [:ENDIF:] `

Single line form

` [:IF(exp,text):] `
` [:IF(exp,text,alternative_text):] `

## IMAGE\_URL ##
> Description:
> Generate a url for a template image from current skins images folder - if not present look in defaults.
> This is just the url - no html tag is included.
Syntax:
` [:IMAGE_URL(image name):] `
Example:
` [:IMAGE_URL(stop):] `
## IMAGE\_URL ##
> Description:
> Generate html <img> tag to display an icon  - if not present look in defaults.<br>
Syntax:<br>
<code> [:ICON(name,[attribute]):] </code>
Example:<br>
<code> [:ICON(stop,width=20):] </code>
<h2>JS_DETAILS</h2></li></ul>

<code> JS_DETAILS([max=&gt;n,fields=&gt;field1|field2|field3...fieldx]) </code>

Output all details for current items in a javascript/json array<br>
if max not provided - all selected rows will be used.<br>
<br>
<code> Example [:JS_DETAILS(max=&gt;4,fields=&gt;TITLE|FILE|EPISODE|PLOT):] </code>

<code> For list of fields see [http://code.google.com/p/oversight/source/browse/trunk/src/dbfield.c dbfield.c] </code>

<h2>LOCKED\_SELECT ##
Display Locked/Unlocked selection.

` [:LOCKED_SELECT:] `
==EPISODE\_COUNT
Number of episodes on this detail page
## LOOP\_END ##
` [:LOOP_END:] - End of names loop body `

## LOOP\_EXPAND ##

` [:LOOP_EXPAND(name=>name,num=>n):] `
` [:LOOP_EXPAND(name=>name,end=>n[,start=>n,inc=>n]):] `
` [:LOOP_EXPAND(name=>name,values=>val1|val2|...|val3):] `

Expand the named loop body replace aoccurences of $loop\_name with the numeric value

## LOOP\_START ##

` [:LOOP_START(name):] - following lines are stored as the named loop body up to the [:LOOP_END:] `

## MENU\_PAGE\_NEXT\_URL ##

Link to previous page URL
` Shorthand for MENU_PAGE_URL(offset=>-1):] `
## MENU\_PAGE\_PREV\_URL ##

Link to previous page URL
` Shorthand for MENU_PAGE_URL(offset=>-1):] `
## MENU\_PAGE\_URL ##

Generate url to jump to the given menu page. Offset is relative from current page.
` [:MENU_PAGE_URL(offset=>1):] `
This should be called from another menu page. To get to menu from details page use the BACK urls.
## ORIG\_TITLE ##
Can Also use $field\_ORIG\_TITLE
## PAGE\_MAX ##
Return the last page number by dividing number of items by the page size (aka grid size).
This does not take delisting into account, which may reduce the number of items.

the page size is determined from the following items:
` - the _page_size skin variable can be used (see [:SET_PAGE(size=>):] also [:SET(...}:] `
- If the variable is not set then it is computed from current rows\*cols. (this will force another parse of the template)

Example:
` [:PAGE_MAX:] `
## PERSON\_ID ##
Return the imdb id of the current actor. This is just the person parameter.(QUERY\_PARAM\_PERSON)

The domain should be passed as a parameter - eg "imdb" or "allocine"

` [:PERSON_ID(domain=>imdb):] `
## PERSON\_ROLE ##

Return the current role of the person Actor, Director or Writer.
The roles are kept seperate to reduce possibility of namesake clashes.
The imdb ids are not used because scraping should not be tied to any
particular site. So the best identifier is name.


## PERSON\_URL ##

Display a link to required domain - default is IMDB

` [:PERSON_URL:] `
## POSTER ##

Display poster for current item.

` [:POSTER:] `
` [:POSTER(attributes):] `

## POSTER\_URL ##

POSTER\_URL(default\_image)
POSTER\_URL(default=>image,index=>nn)
Display image  by looking for fanart for the first db item. If not present then look in the Oversight db, otherwise
use the named image from skin/720 or skin/sd folder. Also see BACKGROUND\_URL FANART\_URL BANNER\_URL THUMB\_URL

## RATING\_STARS ##

RATING\_STARS(numstars)

This will make a rating bar based on the number of stars supplied.
You should have the following stars defined...

eg  Consider a rating of 7.9/10 on a 5 star bar

7.9/10 =~ 3.9/5
So 3 whole stars then a 0.9 star then an empty star.

stat0.png this is an empty star.
star1.png = 0.1 star etc.
star10.png - this is a whole star.

` ==RATING([scale=>scale,precision=>0|1]) `
Multiply rating by scale and round
Oversight Ratings are from 0 to 10

Default scale = 1
Default precision = 1

## SET\_PAGE ##

` [:SET_PAGE(size=>n,[align_data=>1]):] `

This will tell the template the number of elements in a page.
If not present then other macros (eg PAGE\_MAX)  may force a reparse of the template if the page size is not know during the current parse..
This will set temprary variable - _page\_size that will be used to calculate PAGE\_MAX and wrap around behaviour of MENU\_PAGE\_NEXT/PREV\_URL_

If align\_data is set then the correct offset will be added to the fields
FILE\_VOD FILE\_ENC FILE\_PATH FANART\_IMAGE BANNER\_IMAGE THUMB\_IMAGE etc.

> ## SKIN\_NAME ##

> Replace with name of the currently selected skin.
> ## STATUS ##
> > Description:
> > Replace with current status passed from the scanner.

> Syntax:
`   [:STATUS:] `
> Example:
`   [:STATUS:] `
## TEMPLATE\_URL ##
TEMPLATE\_URL(file path)
Return URL to a file within the current skin/template. Fall back to default skin if not found in current skin.
eg.
` [:TEMPLATE_URL(css/default.css):] `
## THUMB\_URL ##

THUMB\_URL(default\_image)
THUMB\_URL(default=>image,index=>nn)
Display small poster image  of db item. If not present then look in the Oversight db, otherwise
use the named image from skin/720 or skin/sd folder. Also see BACKGROUND\_URL FANART\_URL POSTER\_URL BANNER\_URL

## TITLE ##
Can Also use $field\_TITLE
## URL\_BASE ##
Return link to /oversight path that will work on browser or tv.
Example:
```
img src="[:BASE_URL:]/templates/[:SKIN_NAME:]/images/detail/rating_[:RATING(precision=>0):]0.png"/>
```

## WATCHED\_SELECT ##
Display Watched/Unwatched selection.

` [:WATCHED_SELECT:] `