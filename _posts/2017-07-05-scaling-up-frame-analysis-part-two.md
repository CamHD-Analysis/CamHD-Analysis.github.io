---
layout: post
title:  "Scaling out Image Analysis, Part Two:   Making the Docker Image"
categories: lazycache gcp docker
---

[Docker](https://www.docker.com) containers are an essential component of my
scaled analysis.  They bring two big benefits to the table:  First, I can use it
as a kind of heavy-weight package management system, allowing me to wrap up my
software and all its messy dependencies into a monolithic image, and easily
publish that image to a central repository, knowing that all of the dependency
wierdness will be (mostly) ironed out. Second, it lets me separate worker units
from hardware units.   That is, I can turn any computer into a worker unit by
simply downloading and starting the Docker image.   Individual pieces of
hardware (or pieces of virtual hardware) can transparently change roles (or take
on new roles) by starting/stopping Docker images.

My image analysis application runs as a service in a Docker container and
uses `lazycache` to retrieve frames from the videos on the CI.   It can use a
public instance of `lazycache`, but in this case, I also run a cluster of
`lazycache` instances on the worker swarm, providing some degree of parallel
processing.   The frame retrieval is a small (though not trivial) fraction of
the processing time.

These two services are kept in separate Dockerfiles.

## lazycache

The main `lazycache` Docker image is in the [in the `deploy/docker/` directory](https://github.com/amarburg/go-lazycache/blob/master/deploy/docker/Dockerfile) of the [go-lazycache](https://github.com/amarburg/go-lazycache/) repository.

Here are the interesting bits:

    FROM amarburg/golang-ffmpeg:wheezy-1.8

It's based on my
[docker-golang-ffmpeg](https://github.com/amarburg/docker-golang-ffmpeg) image,
which is built on top of the canonical [GoLang Docker
image](https://hub.docker.com/_/golang/) built on Debian --- I used full-fat
Debian, rather than Alpine or similar lightweight Linuxes, to ensure I could get
all of audio-visual dependencies needed for ffmpeg.   The Dockerfile then builds
a recent version of [ffmpeg](http://ffmpeg.org/) from source (using [this script](https://github.com/amarburg/docker-golang-ffmpeg/blob/master/build_ffmpeg.sh)).

    RUN go get -v github.com/amarburg/go-lazycache

    ## Hot patch local files into the repo
    ADD *.go $GOPATH/src/amarburg/go-lazycache/app/

The standard `go get` mechanism is used to download the source code from
Github into the Go environment.   I "hot patch" the source code with
the `main.go` from the current directory, which contains configuration
specific to the Docker version.  In the long run this shouldn't be necessary,
with more of the configuration occurring through config files or environment variables.
Even now the differences are relatively minor.

    WORKDIR $GOPATH/src/github.com/amarburg/go-lazycache/app
    RUN go get -v .
    RUN go build -o lazycache .
    RUN cp lazycache $GOPATH/

Get dependencies, build the application and copy it to `$GOPATH/`.

    ENV LAZYCACHE_PORT=8080
    CMD $GOPATH/lazycache
    EXPOSE 8080

Sets the default port for the app through environmental variables.

Once built, I store a [copy of the image at Docker Hub](https://hub.docker.com/r/amarburg/lazycache_prod/).

## image-analysis

The deployment
tools for the image analysis worker are also stored [on GitHub](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy).
These containers have slightly more going on, so the build and test process
is currently orchestrated through a [Rakefile](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/Rakefile).

There are actually two worker images defined:

  1. `worker_rq_prod` is the _production_ image, which builds the
image analysis tools from a clean check-out from Github.
  1. `worker_rq_test` is the _test_ image.  It copies
the image analysis source tree from the local disk.

Beyond that, the `Dockerfiles` are similar.  Both depend on a [`worker_rq_base` image](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/Dockerfile_rq_base)
which is a base Ubuntu image with all manner of dependencies installed,
including OpenCV and gcc through `apt`, [miniconda]() and a whack of Python tools,
and my `pycamhd-lazycache` Python library.

The [`Dockerfile_rq_prod`](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/Dockerfile_rq_prod) file itself is pretty straightforward:

    FROM camhd_motion_analysis_rq_worker_base:latest
    MAINTAINER Aaron Marburg <amarburg@apl.washington.edu>

Start from the base image.

    WORKDIR /code
    RUN git clone https://github.com/CamHD-Analysis/camhd_motion_analysis.git

    WORKDIR /code/camhd_motion_analysis
    RUN git submodule init && git submodule update

    ## Initial conan configuration
    RUN conan config set settings_defaults.compiler.libcxx=libstdc++11

Clone the code from Github, and initialise the Git submodules, then provide an initial default configuration to [conan](https://www.conan.io)

    ENV BUILD_DIR docker-Release
    ENV VERBOSE 1

    RUN rake release:build

    WORKDIR docker-Release
    RUN make install && make clean
    RUN ldconfig

Build and install the C++ portion of the app.

    VOLUME /output/CamHD_motion_metadata

Define an volume for storing the results,

    ADD launch_worker.sh  /code
    ENTRYPOINT ["/code/launch_worker.sh"]

Finally, the standard entrypoint to the image is a [local shell file](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/launch_worker.sh).  The shell script provides a place for validation before launching the app.  In
this case it checks that the output directory contains a `README.md` file,
my lame attempt at checking that it's really a clone of [CamHD_motion_metadata](https://github.com/CamHD-Analysis/CamHD_motion_metadata).

    #!/bin/bash

    if [ ! -f $OUTPUT_DIR/README.md ]; then
      echo "Could not find output directory $OUTPUT_DIR"
      exit
    fi

    /code/camhd_motion_analysis/python/rq_worker.py "$@"



As above, I used Docker tagging to keep track of various image versions, and
host the production images on [Docker Hub](https://hub.docker.com/r/amarburg/camhd_motion_analysis_rq_worker/).
If I was really worried about security, of course, I could use a private Docker repo,
but then I would have to think about authentication...


While the production workers run in a Docker swarm, and are orchestrated by RQ,
I can run the Docker image standalone to test the worker code.   This is all documentated
(sloppily) in the [Rakefile](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/Rakefile) in the repo.

In production, secrets and configuration are passed to the Docker images using an
environment variable file:

    RQ_REDIS_URL=redis://:myredispassword@my.redis.ip.address/0
    OUTPUT_DIR=/output/CamHD_motion_metadata

I can test different configurations by swapping in different sets of configuration
variables to, for example, connect to testing or production Redis servers.
