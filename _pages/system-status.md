---
layout: page
title: System Status
permalink: /system_status/
---

Two versions of Lazycache are currently live.  These should be identical but since I have to deploy both by hand there may be some time lag.

### Google App Engine

App engine is hooked into the Google "appspot.com" DNS system, so it gets an project-based DNS name.

* [https://ferrous-ranger-158304.appspot.com/v1/org/oceanobservatories/rawdata/files/](https://ferrous-ranger-158304.appspot.com/v1/org/oceanobservatories/rawdata/files/)



### Google Container Engine (Kubernetes)

The GKE instance is currently only at an IP address.  The [nip.io](http://nip.io/) lets me map this to a DNS name:

* [http://lazycache.35.184.13.78.nip.io/v1/org/oceanobservatories/rawdata/files/](http://lazycache.35.184.13.78.nip.io/v1/org/oceanobservatories/rawdata/files/)

 Note the new version has a _new API_ which is slightly different from the old version.  Please start using the new one as much as possible.

 Changes:

  * Adds a version number to the
