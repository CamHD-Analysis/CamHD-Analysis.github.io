---
layout: post
title:  "First performance benchmarks from scaled-out processing"
categories: lazycache gcp docker swarm
---

While I've been working away on [documentation]({{ site.baseurl }}{% post_url 2017-06-16-scaling-up-frame-analysis-part-one %}) on my [scaled-out image]({{ site.baseurl }}{% post_url 2017-07-05-scaling-up-frame-analysis-part-two %})
[analysis procedure]({{ site.baseurl }}{% post_url 2017-07-06-scaling-up-frame-analysis-part-three %}),
my swarms have been humming away in the background, working through the CamHD archive.   As of today (July 7 2017), I've
done optical flow processing on the bulk of 2016, with 2017 in the queue.   The region analysis still
requires careful quality control, but it requires far less processing time.

Before I start throwing out numbers, let me briefly outline how the processing works.  This is jumping ahead a bit, but provides useful context.   I don't pretend this is an optimal, and I'm sure I could reduce the
computational cost.  On the other hand, I'm interested in the relative numbers.   Never mind whether
my algorithm _should_ take an hour per movie.  Instead, given a job which takes an hour per movie, how does that change across my computing options.

It's important to recognize the multiple places where threading is used to max out throughput.  One "job" is the optical flow processing of one movie.   This requires performing an expensive optical flow calculation on every 10'th frame in the movie.
From the top down, then:

 1. The RQ worker is written in Python.  It receives a movie from the work queue, and pulls the movie metadata from Lazycache.
 1. It then uses `dask.threaded` to schedule an array of jobs across all of the local cores, one per frame to be analyzed.
 1. For each frame, an instance of the `frame_stats` C++ program:
    1. Retrieves two frames from Lazycache ... this will be slow and is essentially and IO wait.
    1. Performs optical flow using (currently) the CPU implementations of [DualLTV1](http://docs.opencv.org/2.4.13.2/modules/video/doc/motion_analysis_and_object_tracking.html#createoptflow-dualtvl1) in OpenCV 2.4.x.   Internally, this uses OpenCV's [`parallel_for_`](https://github.com/opencv/opencv/blob/master/modules/core/src/parallel.cpp) abstraction to perform multithreaded loop unrolling.   I use the standard _yakkety_ Ubuntu packages for OpenCV, which I _believe_ means [TBB](https://www.threadingbuildingblocks.org) is used (it's the first choice in the `#ifdef` tree).  
    1. Performs an optimization using [Ceres](http://ceres-solver.org).  I believe Ceres will use multiple threads to evaluate the Jacobian, though I'm not sure if it's necessary in this case.
    1. Does some other bookkeeping, resulting in the frame's results being stored as JSON.
  1. Dask gathers those per-frame JSON results, and generates the whole-movie [`optical_flow.json`](https://github.com/CamHD-Analysis/CamHD_motion_metadata/blob/master/docs/OpticalFlow.md) file.

All of this is done within one [Docker "worker" image]({{ site.baseurl }}{%
post_url 2017-07-05-scaling-up-frame-analysis-part-two %}).   I run two workers
and a lazycache container on every computer in the cluster.   This means each PC
is heavily overloaded, but given the  number of IO waits while communicating
with CI, and other single-threaded code segments, this ensures all system cores
are kept busy, at some task-switching expense.

Based on all this, I assert the processing is network and CPU bound.  Memory usage and disk IO are negligible.

I have two clusters.  My "desktop" cluster consists of three Core i7 machines of different generations.   My Google cloud consists of eight preemptible instances of their [`n1-highcpu-8`](https://cloud.google.com/compute/pricing#predefined_machine_types) running in their `us-central1-a` zone.   The cap of eight instances is essentially arbitrary -- new projects have a default quota of 72 cores,
but I also am running a 1-CPU, non-preemptible `n1-standard-1` instances as swarm manager, Redis server and file server for the cluster.  The preemptible instances save significant running costs but this cluster needs to be refreshed on a daily basis.   This should be straightforward to automate, at least to a minimal level of robustness, but I haven't done it yet.

In terms of specs, my Google cloud machines cost:

<table>
<tr><th>Type</th><th>Virtual CPUs</th><th>Memory (GB)</th><th>Price (USD/hour)</th><th>Notes</th></tr>
<tr><td>n1-standard-1</td><td>1</td><td>3.75</td><td>$0.0100</td><td>Up to 60% discount for <a href="https://cloud.google.com/compute/docs/sustained-use-discounts">sustained use</a></td></tr>
<tr><td>n1-highcpu-8</td><td>8</td><td>7.2</td><td>$0.0600</td><td>Preemptible price</td></tr>
<tr><td></td><td></td><td></td><td>$0.2836</td><td>Standard pricing (FWIW)</td></tr>
</table>

The default processor in the `us-central1-a` zone is a 2.6GHz Xeon E5 "Sandy Bridge."   There are also Ivy Bridge, Broadwell and Skylake machines available, but I haven't experimented with selecting these newer processors.    At present, only Skylake processors carry a price premium.

These machines also incur a disk usage charge of $0.04 / GB / month for their boot disks, which turns out to be pretty negligible.   This processing relies almost exclusively on network ingress (which is free) and intra-zone communications.

** Early on, I used my public Lazycache instances for all processing.  Besides being slower, I also racked up significant egress charges sending images from GAE to my desktop cluster!

Here's the data, spanning 2087 files --- this is not quite all of the videos from 2016.  All times are given as __mean (std dev)__

<table>
<tr><th>CPU</th><th>Threads</th><th>Instances</th><th>Num movies</th><th>Sec. per movie</th><th>Net sec. per frame</th><th>Actual sec. per frame</th></tr>
<tr><td>Core i7-3770K @ 3.5GHz</td><td>8</td><td>1</td><td>263</td><td>5140.33 (1463.13)</td><td>0.21462 (0.04453)</td><td>16.613 (7.535)</td></tr>
<tr><td>Core i7-5820K @ 3.3GHz</td><td>12</td><td>1</td><td>400</td><td>3370.24 (908.48)</td><td>0.14181 (0.02809)</td><td>16.294 (7.584)</td></tr>
<tr><td>Core i7-6700K @ 4.0GHz</td><td>8</td><td>1</td><td>459</td><td>3086.79 (979.91)</td><td>0.12857 (0.03259)</td><td>9.976 (4.959)</td></tr>
<tr><td>Xeon "Sandy Bridge" @ 2.60GHz</td><td>8</td><td>8</td><td>965</td><td>6220.31 (2809.39)</td><td>0.26655  (0.10460)</td><td>20.469 (12.314)</td></tr>
</table>

__Threads__ includes Hyper-threading for the i7 processors (twice the number of physical cores), and is the number of "virtual CPUs" for the cloud compute instances.

__Num movies__ is the number of movies in the sample.  Don't read too much into this number, as the Google cluster was not running for some portion of the processing, so it is undercounted in the final percentages.

__Sec. per movie__ is the total wall time required to process one movie.   Movies __can__ be of different length, but the majority of the sample is the standard 12-13 minute length.

__Net sec. per frame__ is _(total wall time)/(number of frames)_, giving the aggregate throughput of a worker.

__Actual sec. per frame__ is the wall clock time spent analyzing a single frame.  This number is much larger than the net seconds per frame because Dask schedules multiple frames simultaneously.

At this rate, processing a single video on a single cloud  instance requires (on average) 10.37 cents.   Processing all of 2016 would require approx. $238 and 165-processor-days, assuming zero idle time on the virtual machines, and disregarding the cost of the swarm manager node at ~$25/month.   Notably, this cost is __time independent__, I can run my eight instances for 21 days, or 64 instances (512 vCPUs) for 2.6 days _for the same cost_ (assuming you can requisition 64 instances, of course).

FWIW, here are the [Passmark CPU benchmarks](https://www.cpubenchmark.net/) for these processors:

<table>
<tr><th>CPU</th><th>Single Thread mark</th><th>CPU Mark</th></tr>
<tr><td>Core i7-3770K</td><td>2084</td><td>9547</td></tr>
<tr><td>Core i7-5820K</td><td>2016</td><td>12995</td></tr>
<tr><td>Core i7-6700K</td><td>2349</td><td>11110</td></tr>
<tr><td>Xeon "Sandy Bridge" @ 2.60GHz**</td><td>1591</td><td>12275</td></tr>
</table>

** Using the [Xeon E5-2670](http://ark.intel.com/products/64595) which has a base freq of 2.6GHz, 8 cores and 16 threads.   To a casual analysis,
this works out.  The cloud instance, running on 8 virtual CPUs, or "half" of the Xeon, requires approximately twice as long as the i7-5820k
which has a similar CPU mark.   Interesting, the i7-6700K, which is nominally a "lesser" machine than than the i7-5820k, due to the smaller number of physical cores (4 versus 6) is consistently faster in actual performance.  This may be because single-threaded computation remains an important part of the total computational time, or due to other non-compute tasks running on the i7-5820k (which is also my primary development machine).
