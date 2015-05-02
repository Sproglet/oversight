

# Site Checker #

Oversight has a built in site checker. You can use this to confirm that the various TV and movie information websites are available for OVersight to use.

## Red Crosses ##

After using the site checker, if you have a mixture of green ticks and red crosses, it usually means one or more sites are unavailable. This may just affect Movie Fanart, or may affect TV plots etc. Ideally the only site that is optional is http://www.tvrage.com. This is used as a backup to http://www.thetvdb.com for plots only.

If there are no green ticks, and every item shows a red cross then there is a fundamental network issue.

Check the sites work on another PC on your network.
Check your NMT has internet access. Try to use one of the network services. (I will add a new tick for this).

If the above checks are OK then you have encountered a DNS bug on he NMT plaform. This is explained below, but if you dont care about the details and just want things to work.


### Work-Around Method 1 : Disable Reverse-DNS on the router ###

This seems to be the root cause, reorted on the forums. Using a DNS server that does not support reverse DNS properly? Disableing Reverse-DNS on the router should fix.

### Work-Around Method 2 : Change DNS Server on the NMT ###

Go to you Network settings and :
1) If the secondary DNS server is blank then make it the same as whatever is currently in the Primary DNS server settings.

2) Now, change the primary DNS server to a well known one:
Some easy to remember (and type) ones are : 4.2.2.1 , 4.2.2.2 , 4.2.2.4
Or you can use your ISP provided DNS setting (this is in your router configuration)
You can also use OpenDNS ones (although I dont like them on servers for certain technical reasons)

### Work-Around Method 3 : Disable Caching DNS Forwarder on the router ###

(I'm not 100% sure about this. It may be the issue is ultimately between the NMT and your ISPs DNS server.)

Disabling DNS caching at the router may also work around the issue.
This means if you have a DHCP connection, your router will tell it to talk directly to the same DHCP servers that it is using, rather than talking to the router first.
This affects all of the DHCP connections on your network.


## Gory Details ##

(Simplified)

Normally when you go to a website eg www.bbc.co.uk. Your computer needs to find out the ip address first. To do this it asks a DNS server. Most home routers also 'pretend' to be the DNS server for devices on your network. This works perfectly fine, however for some reason the conversation between the NMT and a few router configurations is very slow.

You dont normally notice this except the first time the NMT talks to something it can take about 10 seconds. This should only take a few **milli** seconds. Something is broken.

As a result Oversight says - "nope that is taking too long. Red cross for you"

The reason why you dont normally encounter this issue, with other internet apps on your NMT, is because, Syabas, must have encountered this problem, and decided the best approach is to modify the application that does most of the talking to the internet (wget) to remember what the ip addresses are for each web site. (This is a very non-standard change). Then it only needs to talk to the DNS server once for each web site name.

Seems like a sensible idea, but the problem is that the ip addresses can change. Often every few months.
When this happens wget will look in the wrong place.
The only way wget can get the new ip address is to reboot your NMT (or delete the file /tmp/dns\_cache).

This doesn't really seem like a big problem, but oversight is polling 5 or more different web sites, so its likely one ip address can change every couple of weeks. ( This is not usually a problem with DNS as it has built in a maximum time anyone should 'remember' what a websites IP address is. However this is normally 24 hours. the /tmp/dns\_cache file is only reset at each reboot. )

Anyway, a simple fix is to delete the /tmp/dns\_cache file , before a scan starts,  to make sure 'wget' gets the right address. But then we encounter the DNS Delay bug above!
In which case you need to apply one of the above workarounds to fix.

I will shortly be changing Oversight so it just either :
1. only clears the wget cache maybe once a day  OR
2. Make the site checker reset the cache correctly. The page must load in under 30 seconds, so I have to send out a load of concurrent wgets/lookups and add to the cache.

(I may even use nslookup x.x.x.x 4.2.2.1 and populate the cache directly, but this will fail with http redirects etc. )