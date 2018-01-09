---
title: Running a local copy of lazycache
---

In most cases, if you're making heavy use of Lazycache, it makes sense to
run a local copy.   Lazycache is packaged as a Docker image.   Assuming you have [Docker installed](https://www.docker.com/community-edition#/download), you can
run a local copy from the command line as:

    docker run --rm -p 8080:8080 amarburg/camhd_cache:latest

This will expose your local copy at port 8080.

You can then pass this local URL to the [pycamhd-lazycache](https://github.com/CamHD-Analysis/pycamhd-lazycache) Python module:

```python
import pycamhd.lazycache as lqt

lqt = lqt.lazycache( url="http://localhost:8080/v1/org/oceanobservatories/rawdata/files/")

print( lqt.get_metadata("RS03ASHS/PN03B/06-CAMHDA301/2017/09/30/CAMHDA301-20170930T211500.mov"))
```
