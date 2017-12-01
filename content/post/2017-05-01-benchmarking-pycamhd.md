---
categories: pycamhd lazycache
date: 2017-05-01T00:00:00Z
title: Benchmarking Frame Access Methods
---

Tim and I (Aaron) have been exploring different strategies for making the CamHD video more accessible.   Following our own paths, we've come up with two closely related, yet subtly different tools for pulling individual frames from the HD Quicktime/ProRes files.

There are two big families of tools:

Tim has developed [PyCamHD](https://github.com/tjcrone/pycamhd), a Python library which can efficiently extract single frames from a Quicktime file.

My tools are ... a little more complicated.   I started with the core algorithm from Tim's library and rewrote it in [Go](https://golang.org/) as [go-quicktime](https://github.com/amarburg/go-quicktime).   From there I built an ecosystem which extends the idea in a couple of different directions:

  *  On top of this, [go-lazyquicktime](https://github.com/amarburg/go-lazquicktime) allows extraction of images from Quicktime files either locally or over HTTP, again with transparent caching.  
  <br/>
  go-lazyquicktime is build on the filesystem abstraction layer [go-layzfs](https://github.com/amarburg/go-lazyfs) which allows random, read-only access to both local files  and files served by HTTP (like at the CI).   It also supports transparent caching of those file reads.

  * From there, I built three APIs on top of go-lazyquicktime.   

    * [cgo-lazyquicktime](https://github.com/amarburg/cgo-lazyquicktime) is a C (well, CGo) wrapper around go-lazyquicktime, which lets lazyquicktime be used as a shared library to extend other languages.

    * [cython-lazyquicktime](https://github.com/amarburg/cython-lazyquicktime) is [cython](http://cython.org) wrapper around cgo-lazyquicktime which  brings the go-lazyquicktime tools into Python.

    * [go-lazycache](https://github.com/amarburg/go-lazycache) / [go-lazycache-app](https://github.com/amarburg/go-lazycache-app) is a web server application which provides an HTTP API for browsing the CI and accessing individual images.  It also has strong caching tools built-in.   I've packaged it as a Docker image so it can be deployed locally.   Just to confuse things, I've also written a Python wrapper around the calls to lazycache.  Because this is just a thin wrapper around HTTP calls, it is very lightweight.

Whew, that's confusing.    Here's a summary:

<table class="smaller_table">
  <tr>
    <th>Tool</th>
    <th>Description</th>
    <th>User Interface</th>
    <th>Performance Bottleneck</th>
    <th>Pro</th>
    <th>Con</th>
  </tr>
  <tr>
    <td><a href="https://github.com/tjcrone/pycamhd">PyCamHD</a></td>
    <td>Python library which can extract and decode frames from a local ProRes file.</td>
    <td>Python</td>
    <td>Must download video files first.</td>
    <td>Fast<br/>Easy to deploy (few dependencies)</td>
    <td>Python-only</td>
  </tr>
  <tr>
    <td><a href="https://github.com/amarburg/cython-lazyquicktime">PyLazyQuicktime</a></td>
    <td>Python / Cython wrapper around cgo-lazyquicktime, which is a C wrapper around lazyquicktime (Go).  Can operate on files locally and in-place at CI.</td>
    <td>Python</td>
    <td>Either:
Must download video files first;
Or
network bandwidth to CI</td>
    <td>Fast,<br>flexible</td>
    <td>Complex: many layers, many languages.<br/>
Hard to deploy?</td>
  </tr>
  <tr>
    <td><a href="https://github.com/amarburg/go-lazycache">LazyCache</a></td>
    <td>Web service which uses lazyquicktime to present an HTTP API.  Can run locally or in “the cloud”</td>
    <td>HTTP</td>
    <td>Network bandwidth to CI.<br/>
    All communication from user to service over HTTP.</td>
    <td>Does not require massive local storage.<br/>
Efficient for small numbers of frames from large numbers of videos</td>
  <td>Performance questions.<br/>
Complexity.<br/>
Inefficient for large numbers of frames from single video</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>A minimal python wrapper around HTTP calls to LazyCache</td>
    <td>Python</td>
    <td>As above</td>
    <td>As above</td>
    <td>As above</td>
  </tr>
</table>


# Benchmarking

I developed a set of [sample Jupyter notebooks](https://github.com/CamHD-Analysis/jupyter-lazyqt-benchmarking.git) to benchmark each of these methods.  Note that running PyLazyQuicktime requires a custom Jupyter environment which isn't publicly available yet.

All benchmarks were run on the [CamHD Compute Engine](https://chiron.ldeo.columbia.edu).   Each benchmark required extracting/downloading a randomized set of frames from a single movie.  Performance is measured in average ms of wall clock per frame extracted.

"Direct Disk Access" means the tool is reading directly from the filesystem (from the movies that are local to the Compute Engine).  

"Local HTTP Server" means accessing the local files through an Nginx instance running in a Docker container.

"Rutgers CI" means pulling data from Rutgers via HTTP.

"Local Lazycache Server" is an instance of [lazycache](https://github.com/amarburg/go-lazycache) running on the Compute Engine itself.   This instance is set up to mirror the three different data sources: local filesystem, local via Nginx and direct from Rutgers.

"Google App Engine Lazycache Server" is an instance of Lazycache running in Google App Engine.   It does not have any local copies of the videos and can only pull from Rutgers.

"No[t] cached" means no caching anywhere in the system.

"Yes cached" means data pulled from cache -- in this case, running the benchmark twice and taking the second result.




<table class="smaller_table">
  <tr>
    <th>Method</th>
    <th>Data source</th>
    <th>Cached?</th>
    <th>Mean wall clock<br>(ms / frame)</th>
  </tr>
  <tr>
    <td> <a href="https://github.com/tjcrone/pycamhd">PyCamHD</a> </td>
    <td>Direct disk access</td>
    <td>No</td>
    <td>35.62</td>
  </tr>
  <tr>
    <td>PyLazyQt</td>
    <td>Direct disk access</td>
    <td>No</td>
    <td>37.75</td>
  </tr>
  <tr>
    <td>PyLazyQt</td>
    <td>Local HTTP server</td>
    <td>No</td>
    <td>39.31</td>
  </tr>
  <tr>
    <td>PyLazyQt</td>
    <td>Rutgers CI</td>
    <td>No</td>
    <td>325.01</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Direct disk access</td>
    <td>No</td>
    <td>619.24</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Local HTTP Server</td>
    <td>No</td>
    <td>621.35</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Rutgers CI</td>
    <td>No</td>
    <td>715.74</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Direct disk access</td>
    <td><b>Yes</b></td>
    <td>14.52</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Local HTTP Server</td>
    <td><b>Yes</b></td>
    <td>14.53</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Local Lazycache Server -> Rutgers CI</td>
    <td><b>Yes</b></td>
    <td>15.59</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td>No</td>
    <td>2880.60</td>
  </tr>
  <tr>
    <td>PyLazyCache</td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td><b>Yes</b></td>
    <td>540.74</td>
  </tr>
</table>

PyCamHD and PyLazyQt pull directly from local disk and produce the fastest results, with a slight edge to PyCamHD.   The overhead for pulling the data from a local HTTP server (rather than from the filesystem) is surprisingly minimal, while extracting the data directly from Rutgers brings a roughly order of magnitude decrease in performance --- with the advantage that it requires no local copies of the video files.

Using Lazycache brings its own performance penalties, requiring roughly 20x direct conversion.   Of course there are almost certainly inefficiencies in the system.   The complexity of LazyCache makes these inefficiencies more difficult to find and fix.    However, as shown LazyCache offers a significant speed advantage when pulling from cache.

Finally, the tests against the LazyCache instance running in the cloud shows the performance penalty from contacting the Google server across the internet, even when pulling from the cache.
