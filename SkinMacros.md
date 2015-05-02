Still documenting....



[Auto-generated at Mon Aug  2 22:40:19 GMTDT 2010 from comments in macro.c using macro\_doc in trunk/src]

Oversight skins are html with special macros that are replaced with html text on the fly.

The macros are detailed below.
If this page becomes out of date, refer to macro.c
> ## BACKGROUND\_IMAGE ##
> BACKGROUND\_IMAGE(image name) - deprecated - use BACKGROUND\_URL()
> Display image from skin/720 or skin/sd folder. Also see BACKGROUND\_URL,FANART\_URL
> ## BACKGROUND\_URL ##
> BACKGROUND\_URL(image name)
> Display image from skin/720 or skin/sd folder. Also see FANART\_URL

> ## CONFIG\_LINK ##
> > Description:
> > Generate text to link to a settings configuration form for a config file.

> Syntax:
`   [:CONFIG_LINK(config_file,help_suffix,text[,html_attributes]):] `
> Example:
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

Display a link to IMDB, if person=id is present then a person link otherwise a title link.

` [:EXTERNAL_URL:] `
> ## FAVICON ##

> Display favicon html link.
`   [:FAVICON:] `
## FONT\_SIZE ##
Compute font\_size relative to user configured font size.
Examples:
```
    .eptitle { font-size:100% ; font-weight:normal; font-size:[:FONT_SIZE(-2):]; }
    td { font-size:[:FONT_SIZE:]; font-family:"arial"; color:white; }
```
## GRID ##
Grid Macro has format
` [:GRID(rows=>r,cols=>c,img_height=>300,img_width=>200,offset=>0,page_size=>50):] `

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

> ## IMAGE\_URL ##
> > Description:
> > Generate a url for a template image from current skins images folder - if not present look in defaults.
> > This is just the url - no html tag is included.

> Syntax:
`   [:IMAGE_URL(image name):] `
> Example:
`   [:IMAGE_URL(stop):] `
> ## IMAGE\_URL ##
> > Description:
> > Generate html <img> tag to display an icon  - if not present look in defaults.<br>
</li></ul><blockquote>Syntax:
`   [:ICON(name,[attribute]):] `

> Example:
`   [:ICON(stop,width=20):] `
## LOCKED\_SELECT ##
Display Locked/Unlocked selection.

` [:LOCKED_SELECT:] `
## PAGE\_MAX ##
Return the last page number by dividing number of items by the page size (aka grid size).
This does not take delisting into account, which may reduce the number of items.

the page size is determined from the following items:
1 A page size argument can be supplied, if not
` 2. the _grid_size skin variable can be used (see [:SET(...}:] `
3. If the variable is not set then it is computed from current rows\*cols.

Example:
` [:PAGE_MAX:] `
## POSTER ##

Display poster for current item.

` [:POSTER:] `
` [:POSTER(attributes):] `

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
## WATCHED\_SELECT ##
Display Watched/Unwatched selection.

` [:WATCHED_SELECT:] `