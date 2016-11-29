---
layout: page
title: About
permalink: /about/
---

This is the public website for the <a href="https://www.nsf.gov/">NSF</a>
 <a href="https://www.nsf.gov/funding/pgm_summ.jsp?pims_id=12724">OTIC</a>-funded project "Cloud-Capable Tools for CamHD Data Analysis," a collaborative effort between <a href="http://www.fluidcontinuity.org/">Tim Crone</a>
at Lamont-Doherty Earth Observatory and
<a href="http://apl.washington.edu/people/profile.php?last_name=Marburg&first_name=Aaron">Aaron Marburg</a> at University of Washington Applied Physics Laboratory.

The project came about when Tim and I started to thing about engaging with the data.   We both wanted
to run longitudinal analyses on the videos, but could not see an efficient way to do this
with the files stored on the cyber-infrastructure at Rutgers University.

We quickly ran into a second problem.   Within each video file, the camera pans and zooms across the scene following pre-determined course.  However, the timing of that pattern is not consistent from video to video.   This means the camera is looking at a particular portion of the vent at different times in each video, making it impossible to extract those frames automatically.



The overall project goals are:

* Develop an algorithm for performing fluid velocimetry on CamHD video to estimate video fluid velocity and extent (Tim).
* Develop an algorithm for associating each frame of video with a camera state (position, zoom) (Aaron).
* Build tools and procedures for efficiently processing and reusing video files.
