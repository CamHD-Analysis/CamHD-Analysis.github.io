---
layout: page
title: System Status
permalink: /system-status/
---

  __22 Feb 2017:__ _My pace of development slowed for a while, so I took down the Cluster Enginer / Kuberenetes version.   It was costing real money to keep it going.    We'll see what the running costs on the App Engine version are like..._

  __28 Feb 2017:__  _And to add insult to injury, my $300 free Google Cloud trial has ended and everything has ground to a halt.  It will take me a few days to
  set up billing, then things will be up again....._


<!-- ~~Two~~ One version of Lazycache is currently live.  These should be identical but since I have to deploy both by hand there may be some time lag. -->

----

# General capabilities

These capabilities are available at both endpoints below...  (this is not a substitute for real documentation.)

### Directory structure as JSON:

[/v1/org/oceanobservatories/rawdata/files/](https://ferrous-ranger-158304.appspot.com/v1/org/oceanobservatories/rawdata/files/)

### Movie information as JSON

[/v1/org/oceanobservatories/rawdata/files/RS03ASHS/PN03B/06-CAMHDA301/2017/01/01/CAMHDA301-20170101T000500.mov](https://ferrous-ranger-158304.appspot.com/v1/org/oceanobservatories/rawdata/files/RS03ASHS/PN03B/06-CAMHDA301/2017/01/01/CAMHDA301-20170101T000500.mov)

#### Individual frames from movies as PNG

[/v1/org/oceanobservatories/rawdata/files/RS03ASHS/PN03B/06-CAMHDA301/2017/01/01/CAMHDA301-20170101T000500.mov/frame/5000](https://ferrous-ranger-158304.appspot.com/v1/org/oceanobservatories/rawdata/files/RS03ASHS/PN03B/06-CAMHDA301/2017/01/01/CAMHDA301-20170101T000500.mov/frame/5000)


----

# Deployments

There are currently two public deployments of the software while I evaluate potential platforms.  Both are on the Google Cloud Platform:

## Google App Engine

App engine is hooked into the Google "appspot.com" DNS system, so it gets an project-based DNS name.

* [https://ferrous-ranger-158304.appspot.com/v1/org/oceanobservatories/rawdata/files/](https://ferrous-ranger-158304.appspot.com/v1/org/oceanobservatories/rawdata/files/)

## Google Container Engine (Kubernetes)

The GKE instance is currently only at an IP address.  The [nip.io](http://nip.io/) service lets us map this to a DNS name:

__The version is currently offline while I go through a slow patch.__

* http://lazycache.35.184.13.78.nip.io/v1/org/oceanobservatories/rawdata/files/

 <!-- [http://lazycache.35.184.13.78.nip.io/v1/org/oceanobservatories/rawdata/files/](http://lazycache.35.184.13.78.nip.io/v1/org/oceanobservatories/rawdata/files/) -->
