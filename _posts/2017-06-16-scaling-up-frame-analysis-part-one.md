---
layout: post
title:  "Scaling out Image Analysis, Part One"
categories: lazycache gcp
---

A core assumption of this project has always been that somehow, someday, someone would want to run an algorithm over every CamHD video in the archive.    The central engineering goal has been to come up with a way to do this, and to document how it was done such that others might do the same.   Once we can do this, we can scale up any sort of scientific analysis.

I've written a tool in Python / C++ / OpenCV, [`camhd_motion_analysis`](https://github.com/CamHD-Analysis/camhd_motion_analysis), which uses optical flow to estimate the camera motion.  In its current state it requires about an hour on my desktop to process each video.  Of course, I know a bit of careful redesign might lead to huge efficiency gains, but it works now, and estimating camera motion is an essential component to finding static sections in each video.   So it's time to learn how to scale up....

With the program (a hybrid of Python and C++) in hand, I set out build a process which would let me run `camhd_motion_analysis` on many computers at once, on many videos at once.   I wanted to be able to use both the set of desktops available to me here and an ephemeral set of cloud instances on the [Google Cloud Platform](http://cloud.google.com/).

Beyond that, I wanted:

 * A system which was repeatable and documentable.   To me this means version-controlled scripts and configuration files which accurately record all of the steps necessary to build and run the cluster.

 * To run on both a cluster of desktops and Google with minimal pain/differences between the two.

 * Maximum transparency, minimum confusion

I also recognize that while I want a robust, stable solution that doesn't require much babysitting, I also need to get to working relatively quickly, and long-term stability isn't a huge concern.   My booming dot-com isn't relying on the cluster being available 24/7, and I'm happy to babysit.

I'm pretty happy with the system described here.  Of course, there's still room for improvement, but it has allowed me to get to bulk processing in a relatively short timeframe (particularly including all the time waiting to see if videos are being processed correctly and all of the blind alleys).

First, a pencil sketch:

![Block diagram of cluster]({{site.baseurl}}/images/cluster_pencil_sketch.png)

My solution is built on three components:

 1. [docker](https://www.docker.com) containers
 1. [docker swarm](https://docs.docker.com/engine/swarm/)
 1. [RQ](http://python-rq.org), a Python job-queue library which uses the [Redis](https://redis.io) networked database

My "workers" (the code to analyze a video) is stored in a Docker image.   Docker swarm is then used to start that image on multiple computers (my "swarm"), to monitor those jobs, restart them if they fail, etc.    

The individual jobs are managed by [RQ](http://python-rq.org).   RQ itself is pretty neat, it uses Python pickle to "freeze dry" an entire function call (including arguments) and store it in a Redis datastore.    The workers watch that list, pull those function calls off the stack and execute the function within.   What's neat about this is that the worker doesn't require any application specific code, it's basically (in pseudocode):

    connect to Redis database
    while there's work to do:
      do work

The python script doesn't need to any application-specific `import`s or etc.   __However,__ it does need to be able to find the necessary code somewhere in the Python path.    This makes Docker-izing the analysis code essential as I can write a long and complicated Dockerfile which installs all of the dependencies for my crazy video analysis code, then rapidly push that image out to a bunch of computers in a repeatable manner.

So, with all that said, my cluster code is on Github as [camhd-motion-analysis-deploy](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy).   In later posts I'll walk through the steps to go from nothing to cluster.

 * [Post two]({{ site.baseurl }}{% post_url 2017-07-05-scaling-up-frame-analysis-part-two %}) describes my Docker configuration.
 * And [post three]({{ site.baseurl }}{% post_url  2017-07-06-scaling-up-frame-analysis-part-three %}) discusses RQ configuration
