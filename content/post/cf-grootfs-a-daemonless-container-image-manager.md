---
authors:
- glestaris
categories:
- Cloud Foundry
- Containers
- Docker
- Community
- Open Source
- Linux
- Garden
date: 2016-12-12T16:00:00Z
draft: false
title: "Cloud Foundry GrootFS: A daemonless container image manager"
short: |
  GrootFS is the new container image plugin for Garden, Cloud Foundry's
  container engine. It doesn't require a daemon process, as most other engines,
  and can be run as an unprivileged user, improving CF's security posture.
---

## Background

As part of the CF Garden's move to
[OCI](https://github.com/opencontainers/runtime-spec), we heavily restructured
our previous container engine, Garden Linux, towards a pluggable design. One
interesting area that we can now extend is container image management. CF
GrootFS was developed as a standalone tool that works well with Cloud Foundry
but can also be used independently. In upcoming version 1.1.0 of Garden runC,
CF will be moving closer to start consuming GrootFS thanks to the new plugin
API.

The CF Garden team has been very keen on the work that's being done in the area
of [rootless containers](https://github.com/opencontainers/runc/pull/774),
mainly thanks to [Aleksa Sarai](https://github.com/cyphar). CF aims to be
"secure by default" and reducing the operations that run as host root comprise
a significant portion of this effort. We built GrootFS with this vision in
mind. It hasn't been easy, but in the end, we managed to run the vast majority
of system operations as a non-privileged user.

## I am Groot

GrootFS is developed by a [Cloud Foundry
Foundation](https://www.cloudfoundry.org/) team of engineers. As a result, our
first mandate is to make sure we sufficiently cover the needs of Cloud Foundry.
This however still results in a list of neat features such as:

* Support for Docker and local directory images
* [BTRFS](http://btrfs.wiki.kernel.org/) driver to improve performance of
  already cached images
* Disk quotas
* `grootfs clean` to clean unused layers and meta data
* UID/GID mappings translation (requires the setuid system command
  [`newuidmap`](http://manpages.ubuntu.com/manpages/xenial/man1/newuidmap.1.html)
  to be installed)
* `grootfs stats` to print disk usage (requires a setuid helper binary called
  `drax` to be installed)
* [Metrics](https://github.com/cloudfoundry/dropsonde) emission for performance
  monitoring

### I want to try it

Our main [Github repository](https://github.com/cloudfoundry/grootfs) contains
a playground
[vagrant](https://github.com/cloudfoundry/grootfs/blob/master/README.md) box,
which we recommend using (`vagrant up`) to start playing with GrootFS quickly.

Our [project's
readme](https://github.com/cloudfoundry/grootfs/blob/master/README.md) contains
instructions on how to install and use GrootFS in your environment.

## Examples

### Making an image

Downloading and creating an image can be done with `grootfs create`:

~~~bash
$> grootfs create docker:///alpine my-alpine
/var/lib/grootfs/1000/bundles/my-alpine
~~~

The last argument is the unique image id.

`grootfs create` returns the path to the image directory which contains:

* The `image.json` file which is the image configuration as [defined by the OCI
  image specification](https://github.com/opencontainers/image-spec/blob/master/config.md)
* and the `rootfs` directory which contains the root file system that can be
  used by a container

### Using it with runC

[runC](https://github.com/opencontainers/runc) is the reference implementation
of the OCI [Runtime spec](https://github.com/opencontainers/runtime-spec). It
is the backbone of both Docker and Garden runC today.

runC expects a `rootfs` directory with the contents of the container root file
system in the runtime bundle. However, it can be configured to point to any
directory on the system and indeed, images produced by GrootFS can be
configured in this way.

runC currently requires root to run, but a [rootless
runC](https://github.com/opencontainers/runc/pull/774) will soon be able to
utilise the power of GrootFS and enable us to run the whole process of creating
a container as an unprivileged user.

~~~bash
# Create the root file system
$> grootfs create docker:///ubuntu:16.04 my-ubuntu-container
/var/lib/grootfs/0/images/my-ubuntu-container

# Create the runtime bundle
$> cd /var/lib/grootfs/0/images/my-ubuntu-container
$> runc spec

# cat `/etc/issue` in the container
$> sed -i -e 's/\"sh\"/\"sh\", \"-c\", \"cat \/etc\/issue\"/g' config.json
$> runc run my-ubuntu-container
Ubuntu 16.04.1 LTS \n \l
~~~

In case `sed -i -e 's/\"sh\"/\"sh\", \"-c\", \"cat \/etc\/issue\"/g'
config.json` looks like black magic to you, it's only there to modify the
runtime bundle configuration file (`config.json`) in order to make the
container print the contents of the `/etc/issue` file one it starts.

### Applying disk quotas

Finally, I'd like to demonstrate how to set disk quotas in the produced root
file systems. All you need is to provide the `--disk-limit-size-bytes` flag
with an amount of bytes.

By default the image size is included in the quota. If for example, you use
`docker:///ubuntu:16.04` as an image, this will take ~140 MB of the quota size
which means setting the quota to anything lower than that will fail to create
the image. Alternatively, you can use the `--exclude-image-from-quota` flag to
define a quota that accounts only for the data the container writes and not the
base image:

~~~bash
$> grootfs create --disk-limit-size-bytes 10000 --exclude-image-from-quota docker:///ubuntu:16.04 my-limited-container
/var/lib/grootfs/1000/images/my-limited-container

# Try to write a file bigger than 10 kB
$> dd if=/dev/zero of=/var/lib/grootfs/1000/images/my-limited-container/rootfs/big-file bs=1000 count=11
dd: failed to open '/var/lib/grootfs/1000/images/my-limited-container/rootfs/big-file': Disk quota exceeded
~~~

## Next steps

In the next few weeks, we will focus on improving the performance of GrootFS
when using it concurrently. This work will involve optimising the behaviour
around locking and synchronisation. Not having a daemon makes concurrent
operations harder and the file locking mechanism currently used requires
improvement.

In the same vein, given that BTRFS is a fairly new (relatively to other, more
mature options) file system, we need to make sure that it can perform under the
load the usually hits Cloud Foundry cells. Using BTRFS in earlier Kernels has
been problematic in AWS due to IOPS rate limiting, and we want further
confirmation that using GrootFS in Cloud Foundry environments will not cause
similar issues.
