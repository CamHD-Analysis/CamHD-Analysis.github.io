---
layout: post
title:  "A Brief Tour of LazyCache Part II, Deploying to Google Cloud Platform"
categories: escience lazycache gcp
---

For totally arbitrary, er, I mean perfectly reasonable reasons, I've decided to target [Google Cloud Platform](https://cloud.google.com/) as my strawman "commercial cloud" provider.   I still believe there's a use case for deploying the software --- or some subset of it --- on a local or lab machine, but it certainly makes a lot of sense to have the server *capable* of running in the cloud, whether it's public or strictly private to service a set of local compute instances, so this seemed like a good place to start.

As much as I'm learning Go on the go (heh), I'm learning GCP even more on the, uh, go.   Everything I describe here was figured out on the fly using the $300/60 day trial period for GCP, and I totally respect that I could be doing it completely wrong.    In keeping with my general philosophy, I'm trying to understand the whole process from the bottom up .... with an eye of eventually moving to automation that gives me as much functionality "for free" as possible.

At this point, please don't consider this a HOW-TO, because I'm sure there I've missed steps along the way for setting up a new Google Account, project, enabling APIs, that sort of thing.  This is more of a "I think this is what I'm doing", and with luck this will eventually evolve into a HOWTO/Best Practices documentation.

At a super-high-level, my immediate goals are to:

 * Get [`go-lazycache`](https://github.com/amarburg/go-lazycache) running in the cloud.
 * Do so in a repeatable / documentable manner

This drives a couple of engineering decisions:

 * Package [`go-laycache`](https://github.com/amarburg/go-lazycache) into a [Docker image](https://github.com/amarburg/lazycache-deploy)
 * Run that Docker image in the cloud, in part so I can think long-term about a cluster of Docker images running on a cluster of instances ala [Kubernetes](https://kubernetes.io/)/[Docker Swarm](https://www.docker.com/products/docker-swarm), rather than thinking about specific instances with specific jobs.
 * Store some of the cached file results in online bucket storage.

One thing that's missing right now is connection to a database-like store (whether it's [Google Cloud Datastore](https://cloud.google.com/datastore/) or a NoSQL running in another container).   In the code, there are points where caching to disk is appropriate, and points where caching to a db is more appropriate.  At present I'm only handling the former.

Another big caveat is that `go-lazycache` isn't configurable right now, so it contains some hard-coded paths into Google Cloud Storage, for example.   I obviously need to fix that.

# Basic setup

Right now I'm on the free / trial tier of Google Cloud, and everything is sitting in a single project.   For simplicity, I'll give it the ID _cloud-project-1234_ (if following along, your project will have a different ID, obviously).   Within that project I'm using the [Compute Engine](https://cloud.google.com/compute/):

{:center}
![]({{site.baseurl}}/images/compute_engine_dashboard.jpg)

[Cloud Storage](https://cloud.google.com/storage/):

{:center}
![]({{site.baseurl}}/images/cloud_storage_dashboard.jpg)

and [Container Engine](https://cloud.google.com/container-engine/):

{:center}
![]({{site.baseurl}}/images/container_engine_dashboard.jpg)

For repeatability, I've tried to use the [`gcloud`](https://cloud.google.com/sdk/gcloud/) command line as much as possible, but I haven't spent a lot of time on true automation (like querying status, then run particular commands based on the response).   I think 99% (if not 100%) of what I'm doing can be done exclusively through the website console.

# Building the image

As a touched on in [Part 1]({{site.baseurl}}{% post_url 2017-01-24-current-status %}), I'm using [Wercker](http://www.wercker.com/) for CI and also for building Docker images.   In that post, I described building the [docker-golang-ffmpeg](https://www.github.com/amarburg/docker-golang-ffmpeg) image, my base image which consists of Go and a bunch of FFMpeg libraries.   That project has Wercker automatically push the resulting image to the public [Docker Hub](https://hub.docker.com/r/amarburg/golang-ffmpeg/).

Lazycache is deployed similarly, but the image is stored in the Google Container Registry for the project.  This stores the Docker image in Google Cloud Storage (so you pay for it), but it's private and local to the project.

As previously noted, any manipulation of the Docker image itself by Wercker requires a magic step which can escape from the Docker jail.   This is the `wercker.yml` from [`lazycache-deploy`](https://github.com/amarburg/lazycache-deploy/):

      # wercker version for box creation
      box: amarburg/golang-ffmpeg:wheezy-1.8

      # This is the build pipeline.
      build:
        steps:
            - setup-go-workspace:
                  package-dir: github.com/amarburg/go-lazycache

            - script:
                name: Build Go application
                code: |
                  go get github.com/amarburg/go-lazycache
                  go install github.com/amarburg/go-lazycache/cmd/lazycache-server/

            - internal/docker-push:
              username: _json_key
              password: $GCR_JSON_KEY_FILE
              repository: gcr.io/cloud-project-1234/lazycache-deploy
              registry: https://gcr.io
              entrypoint: /go/bin/lazycache-server
              ports: "5000"
              tag: $WERCKER_GIT_COMMIT, latest
              working-dir: $WERCKER_ROOT


Looks like a standard `wercker.yml`, and again uses the internal [docker-push](http://devcenter.wercker.com/docs/steps/internal-steps#docker-push) step (I know I could have made this more sophisticated with additional pipelines and etc, but this is a good start).   This is cribbed from the wercker documentation on [pushing containers](http://devcenter.wercker.com/docs/containers/pushing-containers).

In this case, rather than pushing to Docker Hub, it pushes to a project-specific location at `grc.io`.   I am still figuring out access control to Google projects, but it looks like the basic level of project access is through service account keys:

{:center}
![]({{site.baseurl}}/images/credentials_dashboard.jpg)

The service account key has an associated JSON file which is a _magic key_ that gives you complete access to the project.  Mostly.  I think.   Well, at least programs which have the contents of the JSON file can get into the project, so it's, like, important for security.

The problem is how to get this critical security information to Wercker.  Sure can't check it into the Github repo (really!).   Wercker gets around this (and other similar problems), by allowing per-project (and per-step, and per-organization), environment variables.   These are set through the website (or the API?) and are associated with the project.  Of course, if it really mattered I think you'd set up a "only for pushing images" key, and a "allowed to access cloud storage key", etc.

{:center}
![]({{site.baseurl}}/images/wercker_environment_variables.jpg)

For `docker-golang-ffmpeg`, the environment variables store my Docker username and password to allow pushing the image back to Docker.  For this project, it stores the contents of a JSON service account key.  

_Note, I learned most of this from a [Wercker blog post](http://blog.wercker.com/deploying-a-microservice-to-gke-with-gcr).  To repeat what Aaron says there:_

> __IMPORTANT! You need to remove any newlines from the JSON file before pasting it in to the Wercker control panel:__

>    tr -d "\n" < /path-to-downloaded-file.json

> __If you miss the above step all push/pull attempts made to GCR will fail and it’ll make you re-evaluate every decision in your life that led up to the moment of the 100th failure. Trust me on that one.__

_Thanks!_


The remaining options to `docker-push` are standard Dockerfile options:  entrypoint, ports, working-dir, etc., and image tags.  This is one of the wierd corners with wercker: it needs to wrap and replicate the Dockerfile format, because you aren't allowed to touch the Dockerfile itself for your project.  Then again, I can't suggest a better solution.

Again, of course all of this could be replicated on your very own desktop.

When all of the above runs correctly, a push to `lazycache-deploy` will fire off a Wercker job, which will build a `lazycache-deploy` Docker image:

{:center}
![]({{site.baseurl}}/images/wercker_lazycache_deploy.jpg)

(or not, sometimes...)

which will end up in Google Container Registry:

{:center}
![]({{site.baseurl}}/images/container_registry.jpg)

Here we can see two revision of the image sitting in the registry, tagged with the `lazycache-deploy` Git commit and `latest`.


# Creating an instance

_n.b. So somewhere in here you authenticate your command line client and set your default project.  I've forgotten how that works, so I assume it's obvious..._

Now that we have a Docker image, we can spin up an instance to host the image.   From the command line, that looks something like:

    gcloud compute instances create go-lazycache  \
          --image-family gci-stable  \
          --image-project google-containers  \
          --address go-lazycache  \
          --metadata-from-file user-data=cloud-init  \
          --tags http-server  \
          --zone us-west1-a  \
          --machine-type f1-micro

This uses the `gcloud` command line to create a new compute instance called `go-lazycache` in the zone `us-west1-a`, of type `f1-micro` (the machine types are described on the [billing page](https://cloud.google.com/compute/pricing#machinetype)).

The address `go-lazycache` is an externally-visible IP address which has been pre-allocated using:

    gcloud compute addresses create "go-lazycache" --region "us-west1"

I believe the tag `http-server` automagically configures the firewall to allow traffic through on port 80.

The new instance is pre-loaded with the latest stable image from the [Container-Optimized OS](https://cloud.google.com/container-optimized-os/docs/) project from Google.   This is the _actual OS which runs on the instance_, and is based on Chromium OS.   It's designed to be mostly what you want (Docker and other stuff) and very little of what you don't (whatever that is).

The part that was hard for me to understand was that up to this point, this instance is utterly generic.   It's like a new, out-of-the-box computer with a fresh install of Linux (or Container-Optimized OS, as the case may be).   It doesn't know a thing about lazycache or who it's supposed to be.

The magic comes from the `metadata-from-file` line.   This adds a [metadata tag](https://cloud.google.com/appengine/docs/java/datastore/metadataqueries) `user-data` to this instance which contains the contents of the file `cloud-init` (which is also in the [lazycache-deploy](https://github.com/amarburg/lazycache-deploy/blob/master/cloud-init) repo).   `cloud-init`, in turn is a [mostly standardized(?)](https://cloudinit.readthedocs.io/en/latest/index.html) system for putting all of your cloud instance configuration in one massive file.   Which, believe it or not, is good for repeatability.

The cloud-init itself is pretty readable YAML (tho it bothers me to cut and paste whole files in the middle of a YAML file, but never mind that....)

    #cloud-config

    users:
    - name: lazycache
      uid: 2000
      groups: docker

    write_files:
    - path: /etc/systemd/system/lazycache.service
      permissions: 0644
      owner: root
      content: |
        [Unit]
        Description=Start the lazycache service in a docker container

        [Service]
        User=lazycache
        Environment="HOME=/home/lazycache"
        ExecStartPre=/usr/share/google/dockercfg_update.sh
        ExecStart=/usr/bin/docker run --rm -u 2000 --publish 80:5000 --name=go-lazycache gcr.io/cloud-project-1234/lazycache-deploy:latest
        ExecStop=/usr/bin/docker stop go-lazycache
        ExecStopPost=/usr/bin/docker rm go-lazycache

    runcmd:
    - systemctl daemon-reload
    - systemctl start lazycache.service

This creates a new user `lazycache` and ensures it is a member of the Docker group, then defines a new [systemd](https://www.freedesktop.org/wiki/Software/systemd/) script.   This runs as that newly created user, and basically does a totally standard `docker run` on the `latest` version of the Docker image we previously stored in Cloud Registry.

> _Just looking at it, I'm sure there are other ways to do it.   For example, the lazycache.service could run on startup by making it dependent on some system service, rather than explicitly `systemctl start`ing it.  Anyway, this works for now._

I found I needed one little bit of black magic here.  By default, I thought that instances in a project were given relatively broad permissions within the project, but initially the instance didn't have permission to pull the Docker image from GCR.  Explicitly calling ``dockercfg_update.sh`` made it work, so it clearly does some authentication, though notably I didn't need to provide any secrets to it.   Come to think of it, I wonder if calling `gcloud docker` rather than `docker` would just work....

Aaaanyway, with this cloud-init, the instance will start up, create a `lazycache-deploy` Docker image, and run it.

{:center}
![]({{site.baseurl}}/images/gcloud_sample_page.jpg)


Neat!

The next step is to increase the configurability of the `lazycache` software itself and figure out how to get that into the image.   For example, right now the Google Cloud Storage bucket is hardcoded, which obviously will break for anyone who tries to use that functionality.

# Party tricks

Just as a note, now that the instance is up and running, you can SSH to it:

    % gcloud compute ssh go-lazycache

    aaron@go-lazycache ~ $ docker ps

    CONTAINER ID        IMAGE                                                  COMMAND                  CREATED             STATUS              PORTS                  NAMES
    c28a3d197782        gcr.io/cloud-project-1234/lazycache-deploy:latest   "/go/bin/lazycache-se"   5 days ago          Up 28 hours         0.0.0.0:80->5000/tcp   go-lazycache

And do Docker-y things.
