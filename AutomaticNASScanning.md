#Settings for scanning NAS

If editing settings via Oversight Setup screen, the initial 'catalog_' prefix, is hidden, so `catalog_watch_paths` appears as `watch_paths`._

Oversight will regularly scan folders listed in the watch\_path settings

If the path does not begin with '/' then the first part should be the name of a network share defined in the NMT setup screen. eg.

```
catalog_watch_paths=mynas/Movies
```

The frequency of scanning is determined by the watch\_frequency keyword.

Or

```
catalog_watch_frequency=2h
```

Oversight will recursively scan all of the watch paths at this time.

**Following settings are not implemented yet. Very soon!**

For efficient scanning it is recommended to use trigger files. This is just a list of files whose datestamp or size will change whenever new content is added to your nas. It mast be visible to the NMT (ideally on the same network share). This allows for more frequent checks for new media.

Eg.

```
catalog_watch_paths=mynas/Movies
catalog_watch_frequency=10m
catalog_trigger_files=mynas/.updated
```

The trigger files are not part of OVersight. It is expected they are remotely updated by the external system/process that adds new content to your NAS. This is a comma seperated list, so avoid commas in filenames.

It is possible to run a separate instance of the catalog script on a Linux based NAS. In this case, the NAS based catalog script can touch a file whenever it adds new content. This is the 'touch\_file' setting.
```
catalog_touch_file=/some/path/on/the/nas/Movies/.updated
```

Then you can make oversight on the NMT , monitor the same file, via the trigger\_files setting.


Also, the catalog script can update the datestamp of all parent folders , when new content is added. So the following setting can be on the remote/NAS catalog script configuration:
```
catalog_touch_parent_folders=1
```

Then, on Oversight/NMT, add the Movies folder itself as a trigger file.
```
catalog_trigger_files=mynas/Movies
```