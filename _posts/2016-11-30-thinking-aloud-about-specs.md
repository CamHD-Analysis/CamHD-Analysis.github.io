---
layout: post
title:  "Thinking out loud about accessing CamHD data"
---

A core driver for this project is the difficulty in performing analyses with the CamHD
data as it sits on the CI at Rutgers.   Each 14-ish minute video collection generates an
11TB Prores file.   At eight files per day, that's about 616 GB/week, or 32TB / year.

It seems like most analyses fall into two broad categories.   Either you download a whole video,
run it through some filter (make a time lapse, analyze the motion of the camera),
or you want to download a small section of the video (perhaps even a few frames).
Either way, processing the entire video archive under the current model
will require downloading all 32TB -- in the first case you need the whole videos.  In the latter
you download, use `ffmpeg` or similar to subset the video and throw away the rest (_never mind that you don't always know which frames you want, more on that later_).

And, having done that, you're basically left with a mirror of the data.   If you want to
share that video among multiple computers (or multiple researchers), you're back to ad hoc methods (shared drives, NFS, etc).

So, the current system is:

* _bandwidth inefficient:_   You need to transfer 32TB from Rutgers, even if you only need a few frames from each video.
* _storage inefficient_  Each researcher working with the data needs to store their 32TB locally.
* _sharing inefficient (??)_

A good zero-order solution would have the CI provide computing assets at Rutgers (near the SAN).   This would solve the bandwidth and storage issues, but puts a huge responsibility onto Rutgers,
who now need to administer (and find funding for) a computing asset alongside a storage asset.   Plus there are questions about how to regulate access to the resource.   And, honestly, not everyone will be satisfied with remote execution of their code.   Most researchers will start out on the desktop, and some would prefer to remain on the desktop for the whole development cycle.

Under the old-fashioned model the responsibility (and costs) for storage and computing are borne by end users.   We want to develop tools which make this style of engagement more efficient.     As a pencil sketch, start with a simple web proxy cache.  A researcher gives the cache a fixed amount of storage (whether GB or TB) and requests CamHD video through the proxy.   The proxy is responsible for downloading the data the first time, and then re-serving files from the cache on subsequent requests.   The cache would adaptively delete video files to stay within it storage quota.

Ignoring issues with scalability, this solution would address the bandwidth inefficiencies in most scenarios.    The cache could be run on a single computer for a researcher working locally, on a server to manage stored video for a cluster, or even in the commercial cloud to support a large user base.

This basic model doesn't address the transfer inefficiency, however.  If I want a single frame from a video, I have to download the whole video, then extract the single frame.   If someone else wants to replicate my results they have to perform the same extraction (though it would at least be fast if they shared my cache). 

The next step is to recognize that whole videos, video subsets and individual frames are all first-class products from the cache.   Using knowledge about the structure of the underlying data, requesting a PNG of frame 1000 from every video should be far more network and storage efficient than requesting an MOV of frame 1000-2000, which should be more efficient than downloading the whole video file.
