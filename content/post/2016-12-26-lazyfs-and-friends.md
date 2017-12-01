---
categories: lazyfs go
date: 2016-12-26T00:00:00Z
title: LazyFS Rev 1
---

I found myself with lots of time to think and very little time to program in December.  This was good as I think my understanding of the CamHD problem evolved over that time, but I wasn't able to really start sketching out ideas.   

I realized one of my mental blocks was choice of languages.   Tim works in Python.   I don't know Python (at least not well enough to really do a good job starting from scratch), preferring Ruby for my scripting needs and C/C++ for compiled languages.   Ruby (Rails?) would be a great choice for sketching the REST-ful API I had in mind, but I had some worries about the "weight" of Rails and long-term maintainability.

So I decided to take a worst-of-all-possible worlds approach and use this as an opportunity to learn a new language.  I've had my eye on both [Rust](https://www.rust-lang.org/en-US/) and [Go](https://golang.org).  Honestly, Rust interested me more, and I learned it first but it didn't take long for my spider-sense to tell me it was a great fit as a C substitute but maybe not for a web application.   So, how about Go?   Obviously they Google imprimatur was worth something, and it seemed to have bigger buzz in the "web applications" space.   Worth a try.

I did the basic [tour](https://tour.golang.org/) and then dove right in.

So I'm now a dangerous amateur, but given a few days I was able to sketch out the basic functionality I had in mind.   I believe I'm following the idiom correctly by breaking my project into a number of repos:

* [LazyFS](https://github.com/amarburg/go-lazyfs) implements the file cache with the `io.ReaderAt` interface

* [Go-Quicktime](https://github.com/amarburg/go-quicktime) parses the tree of Atoms in a Quicktime file.

* [GoAV](https://github.com/amarburg/goav) uses `cgo` to import the FFMpeg API into Go.   Forked from [here](https://github.com/giorgisio/goav).

* [Go-Prores-FFMpeg](https://github.com/amarburg/go-prores-ffmpeg) uses GoAV to decode a frame of ProRes video into a Go Image.

Finally

* [Go-LazyQuicktime](https://github.com/amarburg/go-lazyquicktime) is a test app which ties it all together.  It uses LazyFS to map an HTTP source to a ReaderAt.   It uses Go-Quicktime to parse the file structure, extract metadata about the video (frame size, and location of individual frames), extract a single frame of ProRes from the video, decode it to a Go Image and write it to disk.


Still a ton of rough edges in the software and it's not tested fully end-to-end with the real Rutgers data, but it provides a MWE of what I have in mind.

Besides the long laundry list of improvements, I need to benchmark and document.   I also need to consider the user API.   I believe first priority is the REST-ful API.   This will allow any user to access the core functionality using HTTP.   Long run, some sort of Go-to-Python binding might be a good idea, but it sounds like it's a bit of a challenge (it's really Go-to-C-to-Python?) and the REST-ful API provides a more universal interface.
