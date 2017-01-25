---
layout: post
title:  A Brief Tour of LazyCache
categories: escience lazycache
---

With the time set aside for the eScience Incubator, I've reached a (very) minimal working example of the CamHD caching software which is fully deployable to a [Google Compute Engine](http://cloud.google.com/) instance.   It isn't terribly stable, but that's something I can improve upon.

 It seems like a good time to step back, take stock and document.     At this point I'm going to worry about _how_ I'm doing it.  _What_ and _why_ I'm doing it is a whole 'nother story.

Let's start at the top.  Our caching software is written in Go.   Following the Go idiom, the software is written as a set of modular libraries:

 * [go-lazyfs](https://github.com/amarburg/go-lazyfs) defines an interface for performing random access from files over HTTP.

 * [go-quicktime](https://github.com/amarburg/go-quicktime) parses the tree of Atoms in a [Quicktime](https://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap2/qtff2.html#//apple_ref/doc/uid/TP40000939-CH204-SW1) file.

 * [goav](https://github.com/amarburg/goav) uses `cgo` to import the FFMpeg API into Go.   Forked from [here](https://github.com/giorgisio/goav).

 * [go-prores-quicktime](https://github.com/amarburg/go-prores-ffmpeg) uses `go-quicktime` to find and retrieve individual frames within a movie, then uses `goav` to convert the enclosed data (in ProRes format) into the Go [`Image`](https://golang.org/pkg/image/) format.

These packages are all used to build [go-lazycache](https://github.com/amarburg/go-lazycache), our "app." At heart it's just a web server built using the Go [`net/http`](https://golang.org/pkg/net/http/), but it performs different behaviors depending on the path passed to it.

## Testing the code

Thanks to the flexible Go packaging system, it's pretty straightforward to build a go application.

To run lazycache, need to have `go` __and__ the [FFMpeg](https://www.ffmpeg.org/) libraries (libavcodec, etc.) installed.  Note that there was a period when both Debian and Ubuntu used the alternative [libav](https://libav.org/) libraries which have the same names, but which aren't compatible.   Ubuntu distributions from 2016 (Xenial, etc.) use ffmpeg.

Alternatively, I built a [Docker image](https://hub.docker.com/r/amarburg/golang-ffmpeg/) based on the Debian-based-version of the [official Go language docker image](https://hub.docker.com/_/golang/).   Everything described here can be done in that image (assuming you have [Docker](https://www.docker.com/) installed):

    docker run --tty -i --rm --publish 5000:5000 amarburg/golang-ffmpeg:wheezy-1.8

(the `--publish` is required to expose the webserver ... as shown below)

Assuming [GOPATH has been set](https://golang.org/doc/code.html),

    % cd $GOPATH
    % go get github.com/amarburg/go-lazycache

_(right now, this will spit out a bunch of deprecated function warnings from ffmpeg.   Sorry!)_

This will install `go-lazycache` and all dependencies.

    % go install github.com/amarburg/go-lazycache/cmd/lazycache-server

(it is apparently idiomatic way to put binaries in a Go package in a `cmd/` subdirectory)

This builds the binary `lazycache-server` and installs it in `$GOPATH/bin/`, where can be run:

    % bin/lazycache-server
    [rawdata oceanobservatories org]
    Querying directory: https://rawdata.oceanobservatories.org//
    Could not detect type for /
    registering root node at  /org/oceanobservatories/rawdata/
    Starting http handler at http://0.0.0.0:5000/
    Fs at http://0.0.0.0:5000/org/oceanobservatories/rawdata/
    ....

This will start the application, which will listen on the local port 5000.   Opening a web browser to `http://localhost:5000/org/oceanobservatories/rawdata/files/` should produce some JSON describing the contents of the directory [`http://rawdata.oceanobservatories.org/files/`](http://rawdata.oceanobservatories.org/files/) on the OOI Raw data portal.

{:center}
![]({{site.baseurl}}/images/lazycache_sample_page.jpg)

_Technically speaking `http://localhost:5000/org/oceanobservatories/rawdata/` would work, but the top level at the rawdata archive, `http://rawdata.oceanobservatories.org/` isn't indexable...._


## Docker

Docker forms the next layer of pyramid of tools.   Lazycache can certainly be run standalone, but is intended for deployment as a Docker container.  This brings all of the deployment and versioning benefits of Docker, but also lets us control dependencies (like the FFMpeg version).

Files related to deploying lazycache are stored in a separate repository, [lazycache-deploy](https://github.com/amarburg/lazycache-deploy).   Within that repo, the Dockerfile
will perform the steps detailed above:

    FROM amarburg/golang-ffmpeg:wheezy-1.8

    RUN go get github.com/amarburg/go-lazycache
    RUN go install github.com/amarburg/go-lazycache/cmd/lazycache-server/

    COPY service_account.json /go/
    ENV GOOGLE_APPLICATION_CREDENTIALS=/go/service_account.json

    ENTRYPOINT /go/bin/lazycache-server

    # Document that the service listens on port 5000
    EXPOSE 5000

This builds on the [docker-golang-ffmpeg](https://github.com/amarburg/docker-golang-ffmpeg) image mentioned earlier and essentially runs the same commands as above.   The two lines in the middle re `service_account.json` install a JSON authentication key to access a Google Storage bucket.  Ignore for now.

# Wercker

I've started using [wercker](http://www.wercker.com/) for continuous integration.   CI services allow us to trigger automated processing every time a Github repository is updated.   For individual Go repos, I run built-in test routines.    For Docker images (both `golang-ffmpeg` and `lazycache-deploy`), I can actually build a docker image and automatically push it to a Docker repository (I could do this manually on my laptop, too, of course....)

One minor twist is that Wercker is itself Docker based.   To enroll a repository in Wercker, a `wercker.yml` file must be created in the repository.   This specifies the steps required to build and test the repo.   For `go-lazyfs` this is looks like:

    box: golang

    build:
      steps:
        # Sets the go workspace and places you package
        # at the right place in the workspace tree
        - setup-go-workspace

        - script:
            name: go get
            code: |
              go get -t

        # Build the project
        - script:
            name: go build
            code: |
              go build ./...

        # Test the project
        - script:
            name: go test
            code: |
              go test ./...

Which is pretty straightforward.   It specifies that the tests should run in the Docker image [`golang`](https://hub.docker.com/_/golang/) (the official Go Docker image).   It specifies a single "pipeline" called "build" which contains four steps, first a canned Go setup routine (provided by wercker), then the standard go sequence of get-build-test.   

Interestingly, wercker automatically checks out and works in a copy of the current repository (the one begin tested), so `go get` fetches all of the dependencies for the original repo.   The `go build` and `go test` commands then build and test the current repository.

## Building Docker images in Wercker

This leads to an interesting inside-out arrangement.   Wercker works inside a Docker image.   It would be most efficient to just use Wercker to set up the image as desired, then "can it" and publish it ... but Wercker doesn't provide native access to Docker (you're inside Docker).

To get around this, wercker provides a number of custom "steps" for pushing the current image to Docker Hub, Google, etc.   It's a bit hackish, but works.   The one strangeness is that the construction of Docker images is now defined by the `wercker.yml,` _not_ in a Dockerfile.

For example, this is the wercker.yml for [docker-golang-ffmpeg]()

    box: golang:1.8-wheezy

    build:
      steps:
        - install-packages:
             packages: autoconf bzip2 cmake libtool libssl-dev

        - script:
            name: Configure environment
            code: |
              sh ./environment.sh

        - script:
            name: Build FFMPEG
            code: |
              ./build_ffmpeg.sh

        # Push completed builds to Docker hub
        - internal/docker-push:
            username: $USERNAME
            password: $PASSWORD
            tag: wheezy-1.8
            repository: amarburg/golang-ffmpeg
            registry: https://registry.hub.docker.com

The dirty work is done by the `build_ffmpeg.sh` script.   `internal/docker-push` is the magic step provided by wercker which pushes the final image to Docker hub (in this case).


# Whew

The upshot of all this is that I can make a change to [lazycache](https://github.com/amarburg/docker-golang-ffmpeg) and an updated image will be pushed to Docker hub (eventually).

More in part 2.
