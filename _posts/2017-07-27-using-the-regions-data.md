---
layout: post
title:  "How to use the regions metadata"
categories: regions
---

This is a blog post I've been looking forward to for a long time.   We haven't processed and QC'ed all of the data, but we are starting to make data products for public consumption.   

Along the way, I've needed to grapple with some new questions:

 * Where do I store the public metadata so it will be persistently accessible?
 * How to I publicize the data, make it trackable and citeable?
 * What format should the data be in?   How will end users interact with the data?

This blog post describes my answers to these questions.   It is absolutely a conversation in progress, I'm happy to hear feedback.

# What is the Data

Our contribution to this project is metadata / annotation which accompanies and enhances the [CamHD](http://oceanobservatories.org/instrument-class/camhd/) video stored at the OOI [Raw Data Archive](https://rawdata.oceanobservatories.org/files/RS03ASHS/PN03B/06-CAMHDA301/).

The primary data product is:

>  For every video, estimate the time periods (given as frames within the video) where the camera is still.   When possible, these static periods are tagged relative to a [pre-defined set of camera stations](https://github.com/CamHD-Analysis/CamHD_motion_metadata/blob/master/docs/Regions.md), allowing extraction of frames showing the same field of view from multiple videos.

Secondary data products include:

>  Enumerations of metadata about all videos:   size in bytes, length in seconds, length in frames.

>  A record of estimated camera motion for every N'th frame in a video, as estimated by optical flow.

# DOI and tracking

The data has a DOI provided by Zenodo:   [10.5281/zenodo.834740](https://zenodo.org/record/834741#.WXpJrMbGxE4)

This is the __concept DOI__, it describes the data set.  I am not too worried about release-based DOIs, I would prefer Git commits were used when fine-grain versioning information is needed.

By Zenodo, then, the Bibtex is:

    @misc{aaron_marburg_2017_834741,
      author       = {Aaron Marburg and
                      Timothy J Crone and
                      Friedrich Knuth},
      title        = { {CamHD-Analysis/CamHD_motion_metadata} },
      month        = jul,
      year         = 2017,
      doi          = {10.5281/zenodo.834741},
      url          = {https://doi.org/10.5281/zenodo.834741}
    }

At present, the data is under the [CC-BY-SA-4.0](https://creativecommons.org/licenses/by-sa/4.0/) license, which I consider to be pretty standard academic-ish license.   The data is publicly available as a service from us (not from the NSF, OCL, OOI, or the CI), I accept no liability, and if you use data, please cite us.

# JSON on Github

The mothership for all data is [on Github](https://github.com/CamHD-Analysis/CamHD_motion_metadata),
and the canonical form of the data is as JSON.   

![]({{site.baseurl}}/images/CamHD_motion_metadata_github_screenshot.jpg)

The types and formats of JSON data are described in the repo.   The full data set is biggish for Github (~13GB) but using Github solves the hosting, version control, and issue tracking all in one fell swoop.  The JSON files are _independent_ and you only need to download the files for the video files you're working with .... _or_ you could clone the repo to get all of the files.




I have written a Python library, [pycamhd-motion-metadata](https://github.com/CamHD-Analysis/pycamhd-motion-metadata), which provides
convenience wrappers around the common JSON formats.   It _does not_ handle downloading the data, it assumes you have a local copy of the Git repo .... or at least the JSON files you're interested in.    It contains a number (well, ok, just one) of [examples](https://github.com/CamHD-Analysis/pycamhd-motion-metadata/tree/master/examples) on its use ... many of these also depend on [pycamhd-lazycache](https://github.com/CamHD-Analysis/pycamhd-lazycache).




# CSV

The static regions data in JSON format is also [converted](https://github.com/CamHD-Analysis/CamHD_motion_metadata/blob/master/scripts/regions_to_csv.py) to a tabular format.   A copy is stored in the git repo as [`datapackage/regions.csv`](https://github.com/CamHD-Analysis/CamHD_motion_metadata/tree/master/datapackage).

The contents of the CSV file are:

    mov_basename,date_time,start_frame,end_frame,scene_tag
    CAMHDA301-20160101T000000Z,2016-01-01T00:00:00,581,1051,d2_p1_z0
    CAMHDA301-20160101T000000Z,2016-01-01T00:00:00,1221,1351,d2_p1_z1
    CAMHDA301-20160101T000000Z,2016-01-01T00:00:00,1711,2191,d2_p0_z0
    ...
    ...

The first line contains a descriptive header.   These are the current columns (subject to change):

 * `mov_basename`:  The filename for the movie without an extension.
 * `date_time`: The date/time in UTC for the movie __translated from the movie filename__ to ISO format.   To reiterate:  __this is the date time from the filename, it doesn't have anything to do with the real world time when the video starts, stops, etc__.
 * `start_frame`:   The first frame in this static region.  
 * `end_frame`:  The last frame in this static region.
 * `scene_tag`:   The label applied to this region, may be `unknown` is the classifier was unable to label a scene, or blank if a region hasn't been classifiy.


Accompanying the CSV is a `datapackage.json` which complies with the [frictionless datapackage](http://frictionlessdata.io) metadata standard.  This means their [standard tools](http://frictionlessdata.io/tools/) can be used to access the data:

    import datapackage
    url = "https://raw.githubusercontent.com/CamHD-Analysis/CamHD_motion_metadata/master/datapackage/datapackage.json"

    dp = datapackage.DataPackage(url)
    print(dp.descriptor['title'])

    regions = dp.resources[0]

    d2_p2_z0 = [r for r in regions.iter() if r['scene_tag'] == 'd2_p2_z0']

    print("%d regions" % len(d2_p2_z0))


Other demos are in the [`datapackage/examples/`](https://github.com/CamHD-Analysis/CamHD_motion_metadata/tree/master/datapackage/examples) directory.


# BigQuery

As a test, I have also uploaded the data to the [Google BigQuery](https://bigquery.cloud.google.com/table/camhd-motion-metadata:camhd.movie_metadata) hosted database service.  Standard BQ tools can be used to make queries.   For example, using the `bq` command line:

        > bq query --project_id camhd-motion-metadata "SELECT mov_basename,start_frame,end_frame FROM camhd.regiosn WHERE scene_tag='d2_p0_z0' ORDER BY date_time LIMIT 6"

        Waiting on bqjob_r288eb1c9d004d4d9_0000015d85d0013d_1 ... (0s) Current status: DONE
        +----------------------------+-------------+-----------+
        |        mov_basename        | start_frame | end_frame |
        +----------------------------+-------------+-----------+
        | CAMHDA301-20160101T000000Z |        1711 |      2191 |
        | CAMHDA301-20160101T000000Z |       13101 |     13381 |
        | CAMHDA301-20160101T000000Z |        7531 |      7811 |
        | CAMHDA301-20160101T000000Z |        4691 |      4961 |
        | CAMHDA301-20160101T000000Z |       23601 |     23931 |
        | CAMHDA301-20160101T000000Z |       21031 |     21351 |
        +----------------------------+-------------+-----------+


This isn't unique as far as hosted databases go, but provides an interesting starting point.  I haven't learned any BQ language libraries yet, that's the next step
