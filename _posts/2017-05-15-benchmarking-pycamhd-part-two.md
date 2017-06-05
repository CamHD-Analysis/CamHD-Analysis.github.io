---
layout: post
title:  "Benchmarking Frame Access Methods (again)"
categories: pycamhd lazycache
---


I've made an effort to cleanup and regularize [my benchmarking code](https://github.com/CamHD-Analysis/jupyter-lazyqt-benchmarking.git), and have tested it on my desktop here (in Seattle), on the [CamHD Compute Engine](https://chiron.ldeo.columbia.edu) and on Google Cloud instances.

As [detailed previously]({{ site.baseurl }}{% post_url 2017-05-01-benchmarking-pycamhd %}), we're exploring a few different methods for efficiently extracting individual frames from CamHD movies.  Tim's `pycamhd` module does this extraction in native Python (with help from FFMpeg).   My `lazycache` tool is designed to run as a service with an HTTP API, although coincidentally I've also developed a Python wrapper around the core Go-based frame extraction code.


# Benchmarking

For this round of benchmarking, I'm looking at scalability when parallelized as threads by [Dask](http://dask.pydata.org/en/latest/).  

Each method is asked to perform the same task:   extract 100 random frames drawn
from a set of eight movies.  The total time of task execution is
repeated for 1, 2, 4, and 8 Dask threads.   

All results run on the CamHD Compute Hub, a Core i7-920 with 4 cores.   First I compare Tim's pure-Python PycamHD to my Python-around-C-around-Go PyLazyQt.

<table class="smaller_table">
  <tr>
    <th>Method</th>
    <th>Data source</th>
    <th>Cached?</th>
    <th>1 Threads<br/>Total time (s)</th>
    <th>2 Threads<br/>Total time (s)</th>
    <th>4 Threads<br/>Total time (s)</th>
    <th>8 Threads<br/>Total time (s)</th>
  </tr>
  <tr>
    <td> <a href="https://github.com/tjcrone/pycamhd">PyCamHD</a> </td>
    <td>Direct disk access</td>
    <td>No</td>
    <td>5.08</td>
    <td>2.69</td>
    <td>1.89</td>
    <td>1.53</td>
  </tr>
  <tr>
    <td>PyLazyQt</td>
    <td>Direct disk access</td>
    <td>No</td>
    <td>5.50</td>
    <td>5.50</td>
    <td>5.62</td>
    <td>5.60</td>
  </tr>
  <tr>
    <td>PyLazyQt</td>
    <td>Local HTTP server</td>
    <td>No</td>
    <td>6.20</td>
    <td>6.28</td>
    <td>6.31</td>
    <td>6.42</td>
  </tr>
  <tr>
    <td>PyLazyQt</td>
    <td>Rutgers CI</td>
    <td>No</td>
    <td>41.05</td>
    <td>40.27</td>
    <td>40.64</td>
    <td>39.92</td>
  </tr>
</table>

A couple of take-aways.   First, PyCamHD and PyLazyQT are roughly equivalent operating on local data --- this implies the ProRes decoding (done by FFMpeg) is the primary bottleneck.    Second, PyCamHD scales with threads, by PyLazyQT doesn't.     Normally I would be bummed about this, but it's becoming apparent to me that PyLazyQT is kindof a mutt.   It provides a C API for this functionality which makes it easier to write extensions in other languages, but given we have a pure-Python API in PyCamHD, it doesn't really serve any purpose in the Python ecosystem.   

Next, I tested access through a Lazycache instance running locally on
the CamHD Compute Hub server.  As before, the Lazycache server was configured to
access movies on the local disk, from local disk through a web server, _and_ from CI.


  <table class="smaller_table">
    <tr>
      <th>Method</th>
      <th>Data source</th>
      <th>Cached?</th>
      <th>1 Threads<br/>Total time (s)</th>
      <th>2 Threads<br/>Total time (s)</th>
      <th>4 Threads<br/>Total time (s)</th>
      <th>8 Threads<br/>Total time (s)</th>
    </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Direct disk access</td>
    <td>No</td>
    <td>11.58</td>
    <td>6.53</td>
    <td>4.36</td>
    <td>4.60</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Local HTTP Server</td>
    <td>No</td>
    <td>11.85</td>
    <td>6.79</td>
    <td>4.79</td>
    <td>4.61</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Rutgers CI</td>
    <td>No</td>
    <td>25.31</td>
    <td>12.98</td>
    <td>7.24</td>
    <td>5.03</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Direct disk access</td>
    <td><b>Yes</b></td>
    <td>5.91</td>
    <td>5.14</td>
    <td>5.30</td>
    <td>5.47</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Local HTTP Server</td>
    <td><b>Yes</b></td>
    <td>6.40</td>
    <td>5.27</td>
    <td>5.51</td>
    <td>5.44</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Rutgers CI</td>
    <td><b>Yes</b></td>
    <td>5.97</td>
    <td>5.20</td>
    <td>5.43</td>
    <td>5.36</td>
  </tr>

  </table>

Two interesting patterns emerge.  First, Lazycache is  thread-friendly, providing performance comparable with the baseline (unthreaded PyCamHD) when running in parallel.   It can't touch direct conversion in PyCamHD, which doesn't come as a surprise.    Previous benchmarking has shown that the bottleneck in Lazycache is the PNG encoding, the HTTPS encoding, and serialization onto the network (none of which PyCamHD has to deal with).

The cached results hint that this ~5-6 second baseline represents a hard limit of the system, as a successful cache hit requires no video processing, only two HTTP transmissions (an HTTP redirect to the cached file, then serving the cached file).

We can extend this testing to use a public hosted instance of Lazycache, pulling from CI:

  <table class="smaller_table">
    <tr>
      <th>Method</th>
      <th>Data source</th>
      <th>Cached?</th>
      <th>1 Threads<br/>Total time (s)</th>
      <th>2 Threads<br/>Total time (s)</th>
      <th>4 Threads<br/>Total time (s)</th>
      <th>8 Threads<br/>Total time (s)</th>
    </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td>No</td>
    <td>198.57</td>
    <td>122.12</td>
    <td>105.96</td>
    <td>101.39</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td><b>Yes</b></td>
    <td>89.23</td>
    <td>50.70</td>
    <td>30.53</td>
    <td>25.05</td>
  </tr>
</table>

There is a _huge_ decrease in performance given the network latency between the Compute Hub (in New York) and the GAE instance in Iowa.   

Finally, test querying the Google app engine Lazycache from a Google compute engine instance situated in the same datacenter zone, `us-central-1`.   In theory this node should have maximal real-world bandwidth to the Lazycache app server.   

<table class="smaller_table">
  <tr>
    <th>Method</th>
    <th>Data source</th>
    <th>Cached?</th>
    <th>1 Threads<br/>Total time (s)</th>
    <th>2 Threads<br/>Total time (s)</th>
    <th>4 Threads<br/>Total time (s)</th>
    <th>8 Threads<br/>Total time (s)</th>
  </tr>

  <tr>
    <td>PyLazyCache on Google Compute Engine </td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td>No</td>
    <td>216.46</td>
    <td>98.33</td>
    <td>60.50</td>
    <td>41.83</td>
  </tr>
  <tr>
    <td>PyLazyCache on Google Compute Engine </td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td><b>Yes</b></td>
    <td>152.77</td>
    <td>80.20</td>
    <td>41.93</td>
    <td>20.25</td>
  </tr>
</table>
