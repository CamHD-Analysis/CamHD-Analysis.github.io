---
categories: escience lazycache gcp
date: 2017-02-14T00:00:00Z
draft: true
title: 'My Notes on Trying out Deis Workflow on Google Container Engine, Part 2: Deploying
  an App'
url: /2017/02/14/trying-out-deis-workflow-part2/
---

<!-- [install an application....]({{site.baseurl}}{% post_url 2017-02-14-trying-out-deis-workflow-part2 %}) -->


You've built your [Deis-enabled Kubernetes cluster]({{site.baseurl}}{% post_url 2017-02-13-trying-out-deis-workflow %}), now what?

Deis supports three basic methods for getting an app running on a Deis-ified Kubernetes cluster: by providing Docker images, by providing a Dockerfile, and through a [Heroku](http://heroku.com)-style buildpack.  The latter is very much like the Google App Engine "traditional" environment, where not only the computing, but much of the wrapper around your code is taken care of.

Since I already had a [Dockerfile](https://github.com/amarburg/lazycache-deploy) I decided to try that route first.

    deis keys:add ~/.ssh/id_deis.pub


    % deis create
    Creating Application... done, created nearby-moonrise

    % git push deis master
    Counting objects: 107, done.
    Delta compression using up to 4 threads.
    Compressing objects: 100% (106/106), done.
    Writing objects: 100% (107/107), 11.50 KiB | 0 bytes/s, done.
    Total 107 (delta 64), reused 0 (delta 0)
    remote: Resolving deltas: 100% (64/64), done.
    Starting build... but first, coffee!
    Step 1 : FROM amarburg/golang-ffmpeg:wheezy-1.8
    ---> 243c1be8d91b
    Step 2 : RUN go get github.com/amarburg/go-lazycache-app
    ---> Running in 8e9bd12a4a3f
    ---> e08ebe4a3cbe
    Removing intermediate container 8e9bd12a4a3f
    Step 3 : RUN go install github.com/amarburg/go-lazycache-app
    ---> Running in a73bc53d3423
    ---> 0d3a0b1b210c
    Removing intermediate container a73bc53d3423
    Step 4 : CMD /go/bin/go-lazycache-app --port 80
    ---> Running in 5ecda6c07307
    ---> 594e24b1b9d1
    Removing intermediate container 5ecda6c07307
    Step 5 : EXPOSE 80
    ---> Running in 61b8268b9241
    ---> 116a53f71ea3
    Removing intermediate container 61b8268b9241
    Successfully built 116a53f71ea3
    Pushing to registry
    Build complete.
    Launching App...
    ...
    Done, nearby-moonrise:v2 deployed to Workflow

    Use 'deis open' to view this application in your browser

    To learn more, use 'deis help' or visit https://deis.com/

    To ssh://deis-builder.35.184.13.78.nip.io:2222/nearby-moonrise.git
     * [new branch]      master -> master

What's interesting to me is that it's actually building the Docker image on the cluster....

And lo and behold, it works:

{:.center}
![Kubernetes UI]({{site.baseurl}}/images/lazycache_on_deis.jpg)

And we can see the app running on the Kubernetes desktop:

{:.center}
![Kubernetes UI]({{site.baseurl}}/images/lazycache_kube_desktop.jpg)
