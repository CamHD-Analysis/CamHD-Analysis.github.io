---
layout: post
title:  "Benchmarking Frame Access Methods"
categories: pycamhd lazycache
---


<table>
  <tr>
    <th>Method</th>
    <th>Data source</th>
    <th>Cached?</th>
    <th>Mean wall clock<br>(ms / frame)</th>
  </tr>
  <tr>
    <td> <a href="https://github.com/tjcrone/pycamhd"><b>PyCamHD</b></a> </td>
    <td>Direct disk access</td>
    <td>No</td>
    <td>35.62</td>
  </tr>
  <tr>
    <td><b>PyLazyQt</b></td>
    <td>Direct disk access</td>
    <td>No</td>
    <td>37.75</td>
  </tr>
  <tr>
    <td><b>PyLazyQt</b></td>
    <td>Local HTTP server</td>
    <td>No</td>
    <td>39.31</td>
  </tr>
  <tr>
    <td><b>PyLazyQt</b></td>
    <td>Rutgers CI</td>
    <td>No</td>
    <td>325.01</td>
  </tr>
  <tr>
    <td><b>PyLazyCache</b></td>
    <td>Local Lazycache Server -> Direct disk access</td>
    <td>No</td>
    <td>619.24</td>
  </tr>
  <tr>
    <td><b>PyLazyCache</b></td>
    <td>Local Lazycache Server -> Local HTTP Server</td>
    <td>No</td>
    <td>621.35</td>
  </tr>
  <tr>
    <td><b>PyLazyCache</b></td>
    <td>Local Lazycache Server -> Rutgers CI</td>
    <td>No</td>
    <td>715.74</td>
  </tr>
  <tr>
    <td><b>PyLazyCache</b></td>
    <td>Local Lazycache Server -> Direct disk access</td>
    <td>Yes</td>
    <td>14.52</td>
  </tr>
  <tr>
    <td><b>PyLazyCache</b></td>
    <td>Local Lazycache Server -> Local HTTP Server</td>
    <td>Yes</td>
    <td>14.53</td>
  </tr>
  <tr>
    <td><b>PyLazyCache</b></td>
    <td>Local Lazycache Server -> Rutgers CI</td>
    <td>Yes</td>
    <td>15.59</td>
  </tr>
  <tr>
    <td><b>PyLazyCache</b></td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td>No</td>
    <td>2880.60</td>
  </tr>
  <tr>
    <td><b>PyLazyCache</b></td>
    <td>Google App Engine Lazycache Server -> Rutgers CI</td>
    <td>Yes</td>
    <td>540.74</td>
  </tr>

</table>
