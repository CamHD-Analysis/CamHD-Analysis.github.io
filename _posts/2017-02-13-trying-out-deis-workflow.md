---
layout: post
title:  "My Notes on Trying out Deis Workflow on Google Container Engine"
categories: escience lazycache gcp
---

Over the last couple of weeks I've been exploring the range of offerings from [Google Cloud Platform](https://cloud.google.com/).  I started out working with [base Google Compute Engine (GCE) virtual instances]({{site.baseurl}}{% post_url 2017-01-25-deploying-to-google-cloud %}), as it's the "ground floor" on the technology pyramid and seemed like a good place to start.   With Docker as a common platform, it's [pretty straightforward](https://github.com/amarburg/lazycache-deploy) to spin up single GCE instances which automatically load and run a Docker image.

I then went all the way to the other end of the spectrum, looking at [Google App Engine](https://cloud.google.com/appengine/), which is their highest-level, most abstracted product.   At a very hand-wavy level, App Engine will take raw source code (in Go, Python, Ruby, etc.) and host it in an automatically scaling cluster of instances with all the services you might need: logging, an in-memory cache, cloud data store, etc, plus a bunch of deployment niceties like versioning, rollback, etc.    The only real requirement is that each of your code chunks communicates with everyone else over HTTP, which is a pretty low bar in this magical new micro-services, [12-factor](https://12factor.net) world.   

And so far, App Engine is pretty great.  The only real problem (such as it is) is that you can't get under the hood, should you want to.   And you do pay a small lock-in price as you have to adapt your app to App Engine (responding to particular health check requests over HTTP, for example).  Long-term I think App Engine has the most promise.

But, for the sake of argument there is an in-between option.  [Google Container Enginer](https://cloud.google.com/container-engine/) (GKE ... because GCE was already taken and, uh, because Kubernetes) is a hosted version of the (Google-developed) [Kubernetes](https://kubernetes.io) platform.   Kubernetes is the in-between option in all the best and worst ways.  All the power and configuratability of a great clustering platform, but you need to be comfortable getting into the guts sometimes.

I've been interested in [Deis Workflow](https://deis.com/docs/workflow/), a set of tools designed to "[add] a developer-friendly layer to any Kubernetes cluster, making it easy to deploy and manage applications."  That is, it makes a raw Kubernetes cluster more App-Engine-like.   Seemed worth a try.

For my notes, these are the inital steps for using Workflow to interact with a GKE-hosted Kubernetes cluster.  It's based on the Deis [Quick Start](https://deis.com/docs/workflow/quickstart/)

# Prerequisites

1. Be able to create a GKE cluster through the web interface.   I'm going to use a new project called _"gke-deis-practice"_
1. Have the `gcloud` command-line tool [installed](https://cloud.google.com/sdk/docs/).

  Should be able to do:

    % gcloud projects list
    PROJECT_ID             NAME                     PROJECT_NUMBER
    gke-deis-practice      gke-deis-practice        102832194405

  I've been using configurations to connect to my different projects.   

    % gcloud config configurations list
    NAME                 IS_ACTIVE  ACCOUNT                                             PROJECT                DEFAULT_ZONE  DEFAULT_REGION
    gke-deis-practice    False      amarburg@apl.washington.edu                         gke-deis-practice      us-west1-b    us-west1

    % gcloud config configurations activate gke-deis-practice

  It's actually a bit awkward to work on multiple projects at once.   To create a new configuration, use `gcloud init`

    % gcloud init
    Welcome! This command will take you through the configuration of gcloud.

    Settings from your current configuration [gke-deis-practice] are:
    Your active configuration is: [gke-deis-practice]

    [compute]
    region = us-west1
    zone = us-west1-b
    [core]
    account = amarburg@apl.washington.edu
    disable_usage_reporting = False
    project = gke-deis-practice

    Pick configuration to use:
    [1] Re-initialize this configuration [gke-deis-practice] with new settings
    [2] Create a new configuration
    [3] Switch to and re-initialize existing configuration: [default]
    [4] Switch to and re-initialize existing configuration: [lazycache-appengine]

  Once configured, you should be able to list your container clusters:

    % gcloud container clusters list
    NAME       ZONE        MASTER_VERSION  MASTER_IP        MACHINE_TYPE   NODE_VERSION  NUM_NODES  STATUS
    cluster-1  us-west1-b  1.5.2           104.198.103.249  n1-standard-2  1.5.2         3          RUNNING


# Using kubectl

The main tool for interfacing with a Kubernetes cluster is the command-line tool `kubectl` ([installation instructions here](https://kubernetes.io/docs/user-guide/prereqs/)).   `Kubectl` uses a `kubeconfig` to know which cluster to talk to.   You can supply a `kubeconfig` on the command line, otherwise it looks for a default file at `~/.kube/config`

The `gcloud` utility can be used to automatically set up a `kubeconfig` for the current cluster/project.  This is nice if you're working on one project at a time but I wonder if it leaves you open to problems if you're switching between projects.

The command

    aaron@ursine:~/workspace/camhd_analysis$ gcloud container clusters get-credentials cluster-1
    Fetching cluster endpoint and auth data.
    kubeconfig entry generated for cluster-1.

Will configure `kubectl` for the named cluster in the current project.

If everything is going right, then `kubectl cluster-info` will provide some, uh, cluster info.

    aaron@ursine:~/workspace/camhd_analysis$ kubectl cluster-info
    Kubernetes master is running at https://104.198.103.249
    GLBCDefaultBackend is running at https://104.198.103.249/api/v1/proxy/namespaces/kube-system/services/default-http-backend
    Heapster is running at https://104.198.103.249/api/v1/proxy/namespaces/kube-system/services/heapster
    KubeDNS is running at https://104.198.103.249/api/v1/proxy/namespaces/kube-system/services/kube-dns
    kubernetes-dashboard is running at https://104.198.103.249/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard

This lists a bunch of administrative processes which GKE starts by default.

For what it's worth, there's also a useful web-based dashboard included with Kubernetes.  The simplest way to access it is through the `kubectl proxy` command which will start a local proxy server which connects to the remote UI process:

    aaron@ursine:~/workspace/camhd_analysis$ kubectl proxy
    Starting to serve on 127.0.0.1:8001

{:.center}
![Kubernetes UI]({{site.baseurl}}/images/kubernetes_ui.jpg)


# Install Deis and Helm

Deis is based on the related tool `helm` which is a kind of package manager for Kubernetes clusters.   To use Deis, you need to [install its command line tools](https://deis.com/docs/workflow/quickstart/install-cli-tools/) and [helm](https://github.com/kubernetes/helm#install).  Having done that:

    % deis version
    v2.11.0

doing

    % helm init

will initialize (and install the assocaited `tiller` tool on the __kubernetes cluster__.  Check that helm is working both on the local machine and the server:

    % helm version
    Client: &version.Version{SemVer:"v2.1.3", GitCommit:"5cbc48fb305ca4bf68c26eb8d2a7eb363227e973", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.1.3", GitCommit:"5cbc48fb305ca4bf68c26eb8d2a7eb363227e973", GitTreeState:"clean"}

Then register the package repository for Deis in Helm (on the Kubernetes cluster?)

    % helm repo add deis https://charts.deis.com/workflow

Then install Deis __on the kubernetes cluster__

    % helm install deis/workflow --namespace deis

This simple command sets some pretty big wheels in motion, as it creates all of the Deis processes on the cluster.
If everything goes right, the cluster will have many Deis-related programs running on it (it took a few minutes when I did it)

    % kubectl --namespace=deis get pods
    NAME                                     READY     STATUS    RESTARTS   AGE
    deis-builder-574352672-kr5hb             1/1       Running   5          1d
    deis-controller-3611266332-rnz7l         1/1       Running   3          1d
    deis-database-4237974775-scc51           1/1       Running   0          11h
    deis-logger-176328999-d75ht              1/1       Running   2          11h
    deis-logger-fluentd-7b7qr                1/1       Running   0          1d
    deis-logger-fluentd-v1b5v                1/1       Running   0          1d
    deis-logger-fluentd-vhb6k                1/1       Running   0          1d
    deis-logger-redis-304849759-w37bq        1/1       Running   0          11h
    deis-minio-676004970-6zchb               1/1       Running   0          11h
    deis-monitor-grafana-432496062-bh7sf     1/1       Running   0          1d
    deis-monitor-influxdb-2729657543-pn3vp   1/1       Running   0          11h
    deis-monitor-telegraf-6c6qp              1/1       Running   0          1d
    deis-monitor-telegraf-c562v              1/1       Running   1          1d
    deis-monitor-telegraf-ltfd9              1/1       Running   0          1d
    deis-nsqd-3597503299-81t3n               1/1       Running   0          11h
    deis-registry-586147784-hj2bv            1/1       Running   1          11h
    deis-registry-proxy-72kpd                1/1       Running   0          1d
    deis-registry-proxy-83jxp                1/1       Running   0          1d
    deis-registry-proxy-jstq5                1/1       Running   0          1d
    deis-router-2099956932-t4mzb             1/1       Running   0          11h
    deis-workflow-manager-2528409207-d7wd0   1/1       Running   0          1d


# Connecting to Deis on the cluster

You now need to find the public IP of your cluster.   Deis starts a load-balanced router (apparently) as `deis-router`, and you need to get it's outward-facing IP, as so:

    % kubectl --namespace=deis describe svc deis-router | grep Ingress
    LoadBalancer Ingress:	104.199.124.217

Interestingly, this isn't the same as the GKE endpoint:

{:.center}
![Kubernetes UI]({{site.baseurl}}/images/gke_endpoint.jpg)

Um, ok.

Kubernetes (and App Engine, for what it's worth) use deep stacks of domain names to identify different endpoints within a cluster.   So, for example `http://service.mycluster.org/` would try to talk to the service `service` in the Kubernetes cluster at `mycluster.org`.  Unfortunately, when you're just messing around and only have IP addresses, things get a little messy.

Deis suggests using the service `nip.io` which maps IP addresses to domain names, so `104.199.124.217.nip.io` resolves to _104.199.124.217_, and `service.104.199.124.217.nip.io` also resolves to _104.199.124.217_, which is just what we want.

We can use this to connect to the `deis` service on the cluster:

    % curl http://deis.104.199.124.217.nip.io/v2/
    {"detail":"Authentication credentials were not provided."}

And create the admin user:

    % deis register http://deis.104.199.124.217.nip.io/

The cluster is now ready to [install an application....]({{site.baseurl}}{% post_url 2017-02-14-trying-out-deis-workflow-part2 %})
