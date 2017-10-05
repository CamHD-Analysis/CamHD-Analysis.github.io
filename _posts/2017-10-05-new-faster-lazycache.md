---
layout: post
title:  "Performance improvements to Lazycache"
categories: lazycache
---

I've completed a round of profiling in Lazycache and implemented a few new
features which greatly speed up image retrieval in a couple of important cases:

 * Lazycache now takes the argument `--file-overlay`, which specifies a
   local (on the web server) location containing CAMHD files.  These
   files will be used preferentially over contacting Rutgers directly.
   By default, it expects to have the same directory hierarchy as
   Rutgers (`/RS03ASHS/PN03B/06-CAMHDA301/...`).  If the option `--file-overlay-flatten`
   is specified, it assumes the `*.mov` files are directly in the
   file overlay directory.

   The file overlay directory is read-only, Lazycache won't try to add
   new files.

 * If the option `--allow-raw-output` is given to Lazycache, the server will recognize the
  image extension `.rgba` (in addition to `.png`, `.jpg`, and `.bmp`).
  If specified, the server will return the requested image as the raw (1920 * 1080 * 4) byte
  buffer from the Golang `ImageRGBA` ... which is in RGBA order, row-major.  

    Right now, there's no information in the response to indicate image width/height.
    This raw mode removes the overhead of encoding/decoding the image data, at the expense
    of higher network bandwidth.  Raw mode is probably most useful when
    running a local lazycache instance.

    If this option isn't enabled, Lazycache will return a 501 error.



I've updated [`PyCAMHD-lazycache`](https://github.com/CamHD-Analysis/pycamhd-lazycache)
to match and written some basic benchmarks which are stored in [`jupyter-lazyqt-benchmarking`](https://github.com/CamHD-Analysis/jupyter-lazyqt-benchmarking)
and requires:

 * [pycamhd-lazycache](https://github.com/CamHD-Analysis/pycamhd-lazycache),
    [pycamhd-lazyqt](https://github.com/CamHD-Analysis/pycamhd-lazyqt),
    and my version of Tim's [pycamhd](https://github.com/amarburg/pycamhd).
    My code contains namespacing changes so the three access methods can
    coexist.

  * An instance of Lazycache running on the localhost at port 8080.

  * `--allow-raw-output` is optional

  * The movie `CAMHDA301-20160724T030000Z.mov` should be available by overlay
   if you want to test overlay performance.


From the root of `jupyter-lazyqt-benchmarking`, run

    python -m pytest benchmarks

Here are my results on the [`CamHD Compute Engine`](https://chiron.ldeo.columbia.edu).   A single Lazycache instance is running locally in a Docker image, with the local movies
mounted to the overlay directory.

    ================================================================================================================ test session starts ================================================================================================================
    platform linux -- Python 3.6.0, pytest-3.0.7, py-1.4.33, pluggy-0.4.0
    benchmark: 3.0.0 (defaults: timer=time.perf_counter disable_gc=False min_rounds=5 min_time=5.00us max_time=1.00s calibration_precision=10 warmup=False warmup_iterations=100000)
    rootdir: /home/amarburg/workspace/jupyter-lazyqt-benchmarking, inifile:
    plugins: benchmark-3.0.0
    collected 14 items

    benchmarks/test_get_frame_lazycache.py ..........
    benchmarks/test_get_frame_lazyqt.py ..
    benchmarks/test_get_frame_native.py ..


    ---------------------------------------------------------------------------------------- benchmark: 14 tests ----------------------------------------------------------------------------------------
    Name (time in ms)                                      Min                 Max                Mean            StdDev              Median               IQR            Outliers(*)  Rounds  Iterations
    -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    test_lazyqt_np_overlay                             38.6171 (1.0)       40.3407 (1.0)       39.3264 (1.0)      0.4858 (1.0)       39.2850 (1.0)      0.3961 (3.36)             4;2      14           1
    test_native_np_overlay                             48.7427 (1.26)      52.9020 (1.31)      50.1744 (1.28)     0.9852 (2.03)      50.0356 (1.27)     0.1180 (1.0)              2;2      11           1
    test_lazycache_np_overlay                          55.7623 (1.44)      60.4989 (1.50)      57.3591 (1.46)     1.6009 (3.30)      56.4929 (1.44)     2.3615 (20.01)            1;0      10           1
    test_lazycache_PIL_Image_overlay                   63.8162 (1.65)      67.3159 (1.67)      65.1894 (1.66)     1.1510 (2.37)      65.2892 (1.66)     1.8024 (15.27)            4;0      11           1
    test_lazycache_np_nonoverlay                      147.4370 (3.82)     151.9115 (3.77)     149.2238 (3.79)     1.7569 (3.62)     149.1396 (3.80)     2.4561 (20.81)            2;0       5           1
    test_lazycache_PIL_Image_nonoverlay               152.6328 (3.95)     164.2764 (4.07)     156.8530 (3.99)     4.1821 (8.61)     155.5341 (3.96)     4.3503 (36.85)            2;0       6           1
    test_lazycache_bmp_overlay                        153.0564 (3.96)     165.2168 (4.10)     155.8417 (3.96)     4.6514 (9.58)     154.3438 (3.93)     1.6537 (14.01)            1;1       6           1
    test_native_np_nonoverlay                         207.4045 (5.37)     210.9438 (5.23)     209.4888 (5.33)     1.3674 (2.82)     209.9394 (5.34)     1.8328 (15.53)            2;0       5           1
    test_lazycache_jpg_overlay                        211.7021 (5.48)     213.9330 (5.30)     212.2876 (5.40)     0.9423 (1.94)     211.8330 (5.39)     0.9115 (7.72)             1;0       5           1
    test_lazycache_bmp_nonoverlay                     245.8855 (6.37)     251.0148 (6.22)     248.0708 (6.31)     2.2777 (4.69)     246.7679 (6.28)     3.7615 (31.87)            1;0       5           1
    test_lazycache_jpg_nonoverlay                     296.9355 (7.69)     304.5856 (7.55)     299.9928 (7.63)     2.9171 (6.01)     298.9208 (7.61)     3.5352 (29.95)            2;0       5           1
    test_lazyqt_np_nonoverlay                         340.2875 (8.81)     343.3090 (8.51)     341.1822 (8.68)     1.2825 (2.64)     340.5089 (8.67)     1.6083 (13.62)            1;0       5           1
    test_lazycache_png_overlay                        463.2861 (12.00)    466.0334 (11.55)    464.6884 (11.82)    1.2403 (2.55)     464.8145 (11.83)    2.3160 (19.62)            2;0       5           1
    test_lazycache_png_nonoverlay                     588.3645 (15.24)    597.8325 (14.82)    593.1264 (15.08)    4.1755 (8.60)     594.9978 (15.15)    7.0824 (60.00)            2;0       5           1
    -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    (*) Outliers: 1 Standard Deviation from Mean; 1.5 IQR (InterQuartile Range) from 1st Quartile and 3rd Quartile.
    ============================================================================================================ 14 passed in 26.09 seconds =============================================================================================================


There's a lot going on there.   Here's the basics:

  * Direct conversion in Python (either through Tim's pure Python `native` or my Python-C-Go `lazyqt`) is the fastest, taking approx 40-50 ms per frame when accessing a local file (overlay).

  * My raw-output mode in Lazycache (used to produce either `numpy` or PIL `Image` objects) is pretty effective, taking 60-70ms per frame when
   accessing a local file (overlay).    

  * Raw transfer from Lazycache is also the fastest option (at ~150-160ms each) for files at Rutgers (nonoverlay).   Interestingly, the `native` library pulling from Rutgers is slower, which I can't entirely explain.   

    I _can_ however explain why `lazyqt` is so slow.  The standard `lazyqt` interface doesn't (at present) provide a mechanism for saving movie metadata between calls --- due to the sandwich of languages --- so every frame retrieval with `lazyqt` requires two reads of the movie, one to retrieve the metadata, and a second to get the image data.  Both `lazycache` and the native solution are able to reuse metadata --- this is an entirely solvable problem, but it hasn't been a priority.

  * BMPs are the fastest image format to encode and decode, followed by JPEGs, then PNGs.
