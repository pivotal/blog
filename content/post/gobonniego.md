---
authors:
- cunnie
categories:
- Logging & Metrics
date: 2018-02-18T12:24:22Z
draft: true
short: |
  Traditional single-threaded filesystem benchmark programs may underreport
  results when a slower processor is matched with a fast Solid State Disk (SSD),
  for increases in single-threaded processor performance have not kept pace with
  the advent of fast SSDs. In this blog post we present GoBonnieGo, a
  multi-threaded Golang-based filesystem benchmark program.
title: "GoBonnieGo: A Simple Golang-based Filesystem Benchmark Program"
---

## Are Filesystem Benchmarks Important?

When measuring the speed of our newest disk, the [Samsung 960 Pro (2TB) NVMe
SSD](https://www.anandtech.com/show/10754/samsung-960-pro-ssd-review), we were
surprised to discover that it was xxxx slower than our [Crucial MX300 (1TB)]()

## Tech notes

_What's the difference between filesystem benchmarks and disk benchmarks?_


Filesystem benchmarks generally report slower speeds than disk benchmarks.
filesystem
