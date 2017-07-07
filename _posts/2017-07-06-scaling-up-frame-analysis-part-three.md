---
layout: post
title:  "Scaling out Image Analysis, Part Three: the Redis work queue"
categories: lazycache gcp docker swarm
---

My image analysis tools are trivially parallelizable.  That is, I have a worker
which requires a reasonable block of time (an hour or two) to process one video.
I can process many videos by running this worker on a bunch of computers, and
have them slowly chug through all of the videos on the CI, one at a time.  

To control this mayhem, I'm using a work queue system built around the [RQ](http://python-rq.org)
library for Python.   I've created similar systems in the past with [Resque](http://resque.github.io) for Ruby,
so the concept is pretty familiar to me.   The work queue model provides
just enough robustness, particularly combined with tools that can be selective about
what jobs go into the queue, and which jobs are actually run when pulled from the queue.

In this case, the input for a worker is an URL to a ProRes file at the [raw data
repository](https://rawdata.oceanobservatories.org/files/RS03ASHS/PN03B/06-CAMHDA301/2017/06/14/),
and the output is a corresponding
[`optical_flow.json`](https://github.com/CamHD-Analysis/CamHD_motion_metadata/blob/master/docs/OpticalFlow.md)
file.   I can test for completeness by checking if a `.json` file exists for
each file on the raw data archive.  Outside of extraordinary circumstances, this
lets me write a simple "make sure all of the JSON files exist" script which
injects new jobs into the work queue for any video that doesn't have a
corresponding JSON.   If I want to invalidate an optical flow file, I can simply
delete it and re-run the script.

On the other end, the worker won't overwrite an existing JSON file unless explicitly ordered to do so.
Again, this means I can (accidentally) over-stock the work queue with redundant
jobs requests and not burn a lot of cycles making the same file over and over again.

RQ itself is built on top of [Redis](https://redis.io) datastore.  I'm not really
plumbing the depths of either RQ or Redis, as the default settings work fine.  In this case,
I'm running Redis on a Google Cloud Platform instance** to make it accessible to a cluster running on
a pile of desktops in my office and to a second cluster running in the Google cloud.  In practice, you could run Redis on
a local machine for greater security.   

** I'm running the [Bitnami Redis container](https://github.com/bitnami/bitnami-docker-redis) on a GCP instance.  It's totally stock other than [setting the password](https://docs.bitnami.com/virtual-machine/components/redis/#how-to-change-the-redis-password).   


# Worker

With RQ, the worker side is trivial.   It doesn't need to be customized
to the application at all, as long as the relevant Python modules can be
found in the Python path.   The full worker source code is [here](https://github.com/CamHD-Analysis/camhd_motion_analysis/blob/master/python/rq_worker.py),
but the majority is taken up with command line argument parsing.  Here's the business end:

    conn = Redis.from_url(redis_host)
    with Connection(conn):
        w = Worker( args.queues )
        w.work()

That's it: connect to Redis, get work, do the work.  Of course, to do the work,
Python needs to be able to find all sorts of Python and system dependencies, hence the use of [Docker images]({{ site.baseurl }}{% post_url 2017-07-05-scaling-up-frame-analysis-part-two %})


# Job Injection

The job injector isn't actually much more complicated ([full source here](https://github.com/CamHD-Analysis/camhd_motion_analysis/blob/master/python/rq_client.py)).  As with the worker, it needs to be able to connect to the Redis host.  Otherwise, jobs are queued as:

    q = Queue( connection=Redis.from_url(args.redis) )
      for infile in infiles:
          job = q.enqueue( ma.process_file,
                          infile,
                          outfile,
                          lazycache_url = args.lazycache,
                          num_threads=args.threads,
                          stride=args.stride,
                          start=args.start,
                          stop=args.stop,
                          timeout='1024h',
                          result_ttl = 3600*168,
                          ttl=3600*168 )

Just a simple function call with arguments.   One interesting feature is that
the function args and args to RQ are mixed.  In this case, `timeout`, `result_ttl`
and `ttl` are RQ args, and the rest are for my function `process_file`.   `result_ttl` and `ttl` control the lifespan of pending jobs and jobs results in the Redis datastore.   `timeout` sets the maximum time workers are allowed to run.

The rest of the script is concerned with connecting to the CI, iterating through
the available movies and seeing which have matching JSON files in the local
repo.

For total parity, I prefer to run the injection script inside a worker Docker image (see the `inject` task [here](https://github.com/CamHD-Analysis/camhd-motion-analysis-deploy/blob/master/deploy/Rakefile)).   This lets me use `.env` files for configuration, just as I'm doing with the workers.

__See also [the introductory post]({{ site.baseurl }}{% post_url 2017-06-16-scaling-up-frame-analysis-part-one %}) in this series and [the second post]({{ site.baseurl }}{% post_url 2017-07-05-scaling-up-frame-analysis-part-two %}) on making Docker images.__
