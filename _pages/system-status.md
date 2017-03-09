---
layout: page
title: System Status
permalink: /system-status/
---

  __09 March 2017:__   _Back up with the App Engine version.   Now at a new URL (below)_

----

# General capabilities

These capabilities are available at both endpoints below...  (this is not a substitute for real documentation.)

### Directory structure as JSON:

[/v1/org/oceanobservatories/rawdata/files/](https://camhd-app-dev.appspot.com/v1/org/oceanobservatories/rawdata/files/)

### Movie information as JSON

[/v1/org/oceanobservatories/rawdata/files/RS03ASHS/PN03B/06-CAMHDA301/2017/01/01/CAMHDA301-20170101T000500.mov](https://camhd-app-dev.appspot.com/v1/org/oceanobservatories/rawdata/files/RS03ASHS/PN03B/06-CAMHDA301/2017/01/01/CAMHDA301-20170101T000500.mov)

#### Individual frames from movies as PNG

[/v1/org/oceanobservatories/rawdata/files/RS03ASHS/PN03B/06-CAMHDA301/2017/01/01/CAMHDA301-20170101T000500.mov/frame/5000](https://camhd-app-dev.appspot.com/v1/org/oceanobservatories/rawdata/files/RS03ASHS/PN03B/06-CAMHDA301/2017/01/01/CAMHDA301-20170101T000500.mov/frame/5000)


----

# Deployments


## Google App Engine

App engine is hooked into the Google "appspot.com" DNS system, so it gets an project-based DNS name.

* [https://camhd-app-dev.appspot.com/v1/org/oceanobservatories/rawdata/files/](https://camhd-app-dev.appspot.com/v1/org/oceanobservatories/rawdata/files/)

<!-- ## Google Container Engine (Kubernetes)

The GKE instance is currently only at an IP address.  The [nip.io](http://nip.io/) service lets us map this to a DNS name:

__The version is currently offline while I go through a slow patch.__

* http://lazycache.35.184.13.78.nip.io/v1/org/oceanobservatories/rawdata/files/ -->

 <!-- [http://lazycache.35.184.13.78.nip.io/v1/org/oceanobservatories/rawdata/files/](http://lazycache.35.184.13.78.nip.io/v1/org/oceanobservatories/rawdata/files/) -->
