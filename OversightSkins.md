Oversight has a limited Skin capability.
It comes in the form of templates with macros to replace certain text within html and css pages.



## Modifying Skins ##

Oversight comes with two skins, both of which are immature at the moment.

  * 'default' skin is used for admin pages and should not be touched.
  * 'alt' skin is for menu and tv pages. **This will get overwritten by each upgrade.**

**You can modify the alt skin but you changes will get wiped when upgrading.**

Alternatively you can create a copy of the alt skin, and make you changes there.
To do this simply copy the entire folder

/share/Apps/oversight/templates/alt

to a new folder .eg. to create a skin called 'myskin'

/share/Apps/oversight/templates/**myskin**

Then change the oversight skin setting ovs\_skin\_name in /share/Apps/oversight/conf/oversight.cfg from 'alt' to 'myskin'


## Background Image ##

You can set you own background image for
  * The main menu
  * The TV and Movie pages

### Main Menu Background ###

First it is important to understand that Oversight displays different image depending on the display device. This is due to Gaya browser limitations , and also to a PAL aspect ratio bug.

So if you have SD devices , you will need to create an SD background image, wihch can just be a scaled down version of the HD image. Or you could use the HD image for SD and accept that it will be cropped when viewing on an SD screen.

In the following example **skin\_name** is replaced with the name if the skin you are modifying. You can modify the 'alt' skin directly, but if you want changes to be preserved during upgrades, then you should make a copy of the alt skin, and change that.


To change the main menu background. First edit
/share/Apps/oversight/templates/**skin\_name**/any/menu.template

and change
```
<body [onloadset=:START_CELL:] focuscolor=yellow focustext=black class=menu_background >
```

to
```
<body [onloadset=:START_CELL:] focuscolor=yellow focustext=black class=menu_background background=[:IMAGE(black_desert.jpg):] >
```

Then check the main menu page displays the black\_desert image, rather than a plain black screen.

Now you can change the image.

Put a suitable background image in the following folder:

|Screen Resolution|Folder || Recommended Size|
|:----------------|:------|
|SD|/share/Apps/oversight/templates/**skin\_name**/sd||685x460|
|HD|/share/Apps/oversight/templates/**skin\_name**/720||1280x720|

and change the template file (/share/Apps/oversight/templates/**skin\_name**/any/menu.template) to reference your new file instead of 'black\_desert'

This may need a fix for C200 / 1080 mode.


## Macros ##

The template system is like the C-PreProcessor. It takes a file in, and replaces certain bits of it (MACROS), and spits out the results. Before rendering a html or css page, it is passed through the macro processor.

The syntax is not very nice. (I may overhaul this one day)..

eg.
> `<h3>[:$%TITLE:]</h3>`

will display the title of the current video inside of `<h3>` tags. The exact definition is

> `[optional bit1:macro name:optional bit2]`

The optional bits are only displayed if the results of 'macro name' are defined.


## Simple Macros ##

Simple Macros are replaced with a single piece of text which may be a html query parameter, a value in the oversight dayabase, or a configuration file value. Simple Macros have a 'dollar' character immediately after the first colon..

`[:$macro:]`

### HTML Query Parameter values ###

For HTML Query macros the $ is followed by '?'.

`[:$?name:]`

eg given http://popcorn:8883/oversight/oversight.cgi?view=movie

URL `[:$?view;]` will display "movie"

### Media fields (title, file, watched etc) ###

For Fields from the Oversight database the $ is followed by '%'.

`[:$%field:]`

eg given Movie 'Transformers'

`[:$%YEAR:]` will display the year '2007'

For TV listings only the first item is used. This needs to be improved.

### Configuration Values ###


For Fields from Configuration files the $ is followed by ovs_, catalog_ or unpak_._

`[:$ovs_option_name:]`

`[:$catalog_option_name:]`

`[:$unpak_option_name:]`

## Compound Macros ##

Compound macros are specialist macros that do a specific task. eg. display a list of TV episodes in a certain format `[:TV_LISTING:]`

Compound macros do NOT have a dollar character.

## Macro Index ##

For a full list see SkinMacroIndex

I may overhaul these macros to be more flexible, at present the bes documentation is to look at the [existing templates](http://code.google.com/p/oversight/source/browse/#svn/trunk/templates/default/any) and the [macro\_init function](http://code.google.com/p/oversight/source/browse/trunk/src/macro.c) in the source code.

## Issues ##

At present there are a number of things that hold back general skin development:

  1. Tools for high quality, arbitrary  jpeg resizing running natively on the NMT are not readily available. This may change soon - but until then Gaya uses its own resizing which is pretty nasty.
  1. There are no tools for fancy reflections & transformations on covers. - I can live without this for the time being.
  1. There isn't a 100% clear separation of content and presentation. Some things like the "tv episode listing" use too much hardcoded html.
  1. I made it up as I went along - I created a template system which does allow some flexibility but it doesn't follow any particular standard, so skinners might be reluctant to 'learn it'. It's also not documented - yet - so that doesnt help.