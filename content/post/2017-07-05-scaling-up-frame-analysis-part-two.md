---
categories: lazycache gcp docker
date: 2017-07-05T00:00:00Z
title: 'Scaling out Image Analysis, Part Two:   Making the Docker Image'
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
all of audio-visual dependencies needed for ffmpeg.   The docker-golang-ffmpeg includes [ffmpeg](http://ffmpeg.org/) built from source (using [this script](https://github.com/amarburg/docker-golang-ffmpeg/blob/master/build_ffmpeg.sh)).

The standard `go get` mechanism is used to download the source code from
Github into the Go environment.

    RUN go get -v github.com/amarburg/go-lazycache

    ## Hot patch local files into the repo
    ADD *.go $GOPATH/src/amarburg/go-lazycache/app/

I "hot patch" the source code with
the `main.go` from the current directory, which contains configuration
specific to the Docker version.  In the long run this shouldn't be necessary,
with more of the configuration shifting through config files or environment variables, but it was a cheap and easy way to implement version-specific changes.
Even now the differences are relatively minor.

Then get dependencies, build the application and copy it to `$GOPATH/`:

    WORKDIR $GOPATH/src/github.com/amarburg/go-lazycache/app
    RUN go get -v .
    RUN go build -o lazycache .
    RUN cp lazycache $GOPATH/

And some Docker image configuration.   Lazycache uses post 8080 by default,
the standard port of microservices in [GAE](https://cloud.google.com/appengine/).

    ENV LAZYCACHE_PORT=8080
    CMD $GOPATH/lazycache
    EXPOSE 8080

Once built, I push a copy of the image to [Docker Hub](https://hub.docker.com/r/amarburg/lazycache_prod/).

## image-analysis

The deployment
tools for the image analysis worker are also stored [on GitHub](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy).
These containers have slightly more going on, so the build and test process
is currently orchestrated through a [Rakefile](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/Rakefile).

There are actually two worker images defined:

  1. `worker_rq_prod` is the _production_ image, which builds
`camhd_motion_analysis` from a clean clone from Github.
  1. `worker_rq_test` is the _test_ image.  It copies the `camhd_motion_analysis` source from a the local disk, then builds in the Docker image.

The `Dockerfiles` are otherwise similar.  Both depend on a [`worker_rq_base` image](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/Dockerfile_rq_base)
which is a base Ubuntu image with all manner of dependencies installed,
including OpenCV and gcc through `apt`, [miniconda](), a whack of Python tools,
and my [`pycamhd-lazycache`](https://github.com/CamHD-Analysis/pycamhd-lazycache) Python library.

The [`Dockerfile_rq_prod`](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/Dockerfile_rq_prod) file itself is pretty straightforward.  It starts from the base image:

    FROM camhd_motion_analysis_rq_worker_base:latest
    MAINTAINER Aaron Marburg <amarburg@apl.washington.edu>

Clone the code from Github, and initialize the Git submodules, then provide an initial default configuration to [conan](https://www.conan.io)

    WORKDIR /code
    RUN git clone https://github.com/CamHD-Analysis/camhd_motion_analysis.git

    WORKDIR /code/camhd_motion_analysis
    RUN git submodule init && git submodule update

    ## Initial conan configuration
    RUN conan config set settings_defaults.compiler.libcxx=libstdc++11

Build and install the C++ portion of the app.

    ENV BUILD_DIR docker-Release
    ENV VERBOSE 1

    RUN rake release:build

    WORKDIR docker-Release
    RUN make install && make clean
    RUN ldconfig

Define an volume for storing the results,

    VOLUME /output/CamHD_motion_metadata

Finally, the standard entrypoint to the image is a [local shell file](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/launch_worker.sh).  

    ADD launch_worker.sh  /code
    ENTRYPOINT ["/code/launch_worker.sh"]

The shell script provides a place for validation before launching the app.  In
this case it checks that the output directory contains a `README.md` file,
my lame attempt at checking that it's really a clone of [CamHD_motion_metadata](https://github.com/CamHD-Analysis/CamHD_motion_metadata).

    #!/bin/bash

    if [ ! -f $OUTPUT_DIR/README.md ]; then
      echo "Could not find output directory $OUTPUT_DIR"
      exit
    fi

    /code/camhd_motion_analysis/python/rq_worker.py "$@"


Again, I use Docker tags to keep track of image versions, and
distribute the production images through [Docker Hub](https://hub.docker.com/r/amarburg/camhd_motion_analysis_rq_worker/).
If I was really worried about security, of course, I could use a private Docker repo,  but then I would have to think about authentication...


While the production workers run in a Docker swarm, and are orchestrated by RQ,
I can run the Docker image standalone to test the worker code.   This is all
documented (sloppily) in the
[Rakefile](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/docker/Rakefile)
in the repo.

Secrets and configuration are passed to the Docker images using an
environment variable file using the `--env-file` arg to Docker:

    RQ_REDIS_URL=redis://:myredispassword@my.redis.ip.address/0
    OUTPUT_DIR=/output/CamHD_motion_metadata

I can test different configurations by swapping in different sets of configuration
variables:

    docker run --env-file prod.env amarburg/camhd_motion_analysis_rq_worker:latest

or

    docker run --env-file test.env amarburg/camhd_motion_analysis_rq_worker:latest

For example, to have the workers connect to different Redis instances (or different queues on the same instance).

__See also [the introductory post]({{ site.baseurl }}{% post_url 2017-06-16-scaling-up-frame-analysis-part-one %}) in this series and [the third post]({{ site.baseurl }}{% post_url  2017-07-06-scaling-up-frame-analysis-part-three %}) on working with RQ.__
