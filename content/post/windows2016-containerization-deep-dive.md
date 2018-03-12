---
authors:
- aminjam
- sbhatia

categories:
- CF Runtime
- Diego
- Windows
- Containers
- .NET
date: 2018-03-12T11:25:15-04:00
draft: true
short: |
  Technical details for how we implemented containers on Windows 2016 Server Core for Pivotal
  Cloud Foundry.
title: "Implementing Windows Server Containers for Cloud Foundry : A Deep Dive"
---

Hey, have you heard? Recently, Pivotal Cloud Foundry supports running
applications in [Windows Server Containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/about/).
This post is meant to be an update to our previous deep dive for how [containers worked on Windows 2012R2](http://engineering.pivotal.io/post/windows-containerization-deep-dive/).

Garden-runC Release and windows
-------------------------
Previously, for applications running on Windows2012R2 stack, garden-windows team implemented [garden API](https://code.cloudfoundry.org/garden) and
maintained [garden-windows-bosh-release](https://github.com/cloudfoundry-incubator/garden-windows-bosh-release).
Currently, windows2016 implementation has taken
advantage of pluggable nature of [Guardian](https://code.cloudfoundry.org/guardian)
and only implements the Runtime, Network, and Image plugins for windows2016.
- [__winc__](https://code.cloudfoundry.org/winc): This is the
OCI Runtime Plugin for creating and running containers in windows2016 stack.
- [__winc-network__](https://code.cloudfoundry.org/winc): This is the
Nework Plugin for [Guardian](https://code.cloudfoundry.org/guardian).
- [__groot-windows__](https://code.cloudfoundry.org/groot-windows): This is the
Image Plugin for managing container images and setting up a root filesystem. This plugin can be used with local OCI image or remote Docker URIs.

Windows Container Isolation
---------------------------

Windows Server 2016 is shipped with Windows Server Containers, similar to the primitives
found in the Linux kernel. We use the official [hcsshim](https://github.com/Microsoft/hcsshim)
Go library for instrumenting the Windows Server Containers in Cloud Foundry.
Windows Server Container provide application isolation through process and namespace isolation technology.
A Windows Server container shares a kernel with the container host and all containers running on the host.

Here are some of the details on how Garden-Windows secures applications:

* __Filesystem isolation__: Windows Server Containers now by
default use a temporary scratch space on the container host's system drive for storage
during the lifetime of the container. This allows us to have a dedicated file system
(e.g. Access to `C:\`) inside of the container. Any modifications made to the
container file system or registry is captured in a sandbox managed by the host.
As a result, we are now able to create and maintain a root file system (rootfs) that allows
applications to receive security upgrades when running on the platform.

* __Disk usage__: Disk usage limits are enforced by NTFS [disk
  quotas](https://technet.microsoft.com/en-us/library/cc938945.aspx#XSLTsection128121120120)
  in both Window2012R2 and Window2016 stack.
  Previously, this quota applied to all files owned by a given user, but with Windows Server Containers
  the quota is now applied to the Sandbox image.

* __Network isolation__: Windows Server Containers each have a network compartment
which is analogous to how the Linux containers work.

* __Memory usage__:  TODO
* __CPU usage__: TODO

We at Pivotal believe that .NET is an important enterprise platform and are
committed to the success of the project. We’re also excited about future
opportunities for .NET on Cloud Foundry, including .NET Core and our [Steel
Toe](http://steeltoe.io/) initiative. The user experience and adding new features
is so much better compared to our support for Windows 2012R2.

We hope that this serves as a good introduction to containers as they have been
implemented on Windows 2016. Our team is always available on
[Slack](https://cloudfoundry.slack.com/messages/garden-windows/) to answer any
questions you may have.
