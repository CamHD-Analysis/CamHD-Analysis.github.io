---
layout: post
title:  "Benchmarking Frame Access Methods II, Google Compute Engine"
categories: gce lazycache
---

Following on the [first round of benchmarking]({{ site.baseurl }}{% post_url 2017-05-01-benchmarking-pycamhd %}), I repeated the Lazycache-oriented portion of the benchmarks from a Google Compute Engine instance.

To do this I started a GCE instance in the same zone (but in a different project) as my Google App Engine Lazycache instance.   I used a _n1-highcpu-4 (4 vCPUs, 3.6 GB memory)_ running Ubuntu 16.04LTS.  Once the machine was provisioned I installed [Miniconda](https://conda.io/miniconda.html) manually, and then Jupyter notebook and all of the dependencies.

In a Jupyter notebook I ran a subset of the [Lazycache Benchmarking](https://github.com/CamHD-Analysis/lazyqt_demo_notebooks/blob/master/Lazycache%20Benchmarking.ipynb) notebook from my [demo notebooks](https://github.com/CamHD-Analysis/lazyqt_demo_notebooks).



<table class="smaller_table">
  <tr>
    <th>Method</th>
    <th>Data source</th>
    <th>Cached?</th>
    <th>Mean wall clock<br>(ms / frame)</th>
  </tr>
  <tr>
    <td>PyLazyCache on GCE</td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td>No</td>
    <td>2684.39</td>
  </tr>
  <tr>
    <td>PyLazyCache on GCE</td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td>Yes</td>
    <td>~200<br/>(see below)</td>
  </tr>
</table>

Relative to the [previous results]({{ site.baseurl }}{% post_url 2017-05-01-benchmarking-pycamhd %}) the performance is essentially equal for the first retrieval from Lazycache (which is by far the slowest way to get data), but it is about twice as fast for cache retrievals.  I have to admit I expected cache retrieval within a data center (done by HTTP access to a Google Cloud bucket) to be very fast....

I ran the test multiple times and saw a fair amount of variability in cache retrieval times:

![Graph of cache retrieval times]({{site.baseurl}}/images/gae_gce_lazycache_extraction_time.png)
