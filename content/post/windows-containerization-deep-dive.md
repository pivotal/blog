---
authors:
- mhoran
- cvieth
categories:
- CF Runtime
- Diego
- Windows
- Containers
- .NET
date: 2016-04-26T11:25:15-04:00
draft: false
short: |
  Technical details for how we implemented containers on Windows for Pivotal
  Cloud Foundry.
title: "Implementing Containers on Windows: A Deep Dive"
---

Hey, have you heard? Since last fall, Pivotal Cloud Foundry supports running
applications on Windows. As part of the process for supporting this, we
implemented Diego’s [Garden](https://github.com/cloudfoundry-incubator/garden)
API on [Windows](https://github.com/cloudfoundry/garden-windows), and
cross-compiled [Diego](https://github.com/cloudfoundry-incubator/diego-release)
and [Loggregator](https://github.com/cloudfoundry/loggregator) components for
Windows. Implementing garden-windows required us to come up with a way to
“containerize” applications on Windows. Here’s how we did it.

Linux Container Isolation
-------------------------
On Linux, applications deployed to Cloud Foundry are run inside
[containers](https://en.wikipedia.org/wiki/Operating-system-level_virtualization).
Both DEA and Diego-based CF deployments use low-level [Linux
APIs](https://en.wikipedia.org/wiki/Cgroups) to create a “container” environment
that isolates the contents of each container from one another, and from the
host. This is the same technology used by Docker and other high-level container
technologies.

In Diego, this component is called Garden and is currently being rewritten to
use the same API as Docker, [RunC](https://github.com/opencontainers/runc).

Containers are popular because they provide strong isolation between
applications, without the overhead of virtualization technology. Two
applications deployed on the same machine have an isolated filesystem and
process list, preventing cross-application interference. On Linux, containers
even have their own isolated network stack. An application running inside one
container can bind to the same ports used by another container on the same
machine.

For the most part, users can treat a container on Linux just like you would
treat a VM -- though containers are lighter-weight and have less overhead.

Specifically, containerization on Linux provides isolation in the following ways:

* __Filesystem isolation__: one container cannot read or modify the files outside of
  its own container filesystem (i.e. those of the host or of other containers).
* __Disk usage__: disk usage can be limited with a quota.
* __Network isolation__: the ports available to processes within a Linux container
  are namespaced to that container. Other containers on the same host can bind
  to the same ports, and by default traffic is disallowed to those ports unless
  mapped to the outside world.
* __Memory usage__: one application cannot use more than a pre-set amount of the
  memory on a single VM host.

Windows Container Isolation
---------------------------

In designing Windows support for Cloud Foundry, we decided to take a
containerized approach to application deployment. We chose containers over
virtual machines due to the lightweight nature of containers when compared to
their VM counterparts. This also brings the experience in line with that of
Linux.

Windows Server 2012 provides process isolation primitives, similar to those
found in the Linux kernel. We’ve contributed to an open source project called
[IronFrame](https://github.com/cloudfoundry/IronFrame) to abstract these kernel
primitives into an API which Garden utilizes. The low-level APIs available on
Windows differ from those on Linux. As a result, the functionality of our Garden
implementation on Windows is slightly different.

Here are some of the details on how Garden-Windows secures applications:

* __Filesystem isolation__: In order to take advantage of native Windows Access
  Control Lists (ACLs), IronFrame creates a unique, standard user for each
  container created. Files in the containerizer directory (C:\containerizer by
  default) are ACL’d such that they are only readable by the temporary user that
  owns the container. Just like standard users on a Windows workstation, these
  container users will still be able to read much of the host OS’s filesystem
  (e.g. system DLLs and C:\Program Files\), so care should be taken not to store
  sensitive or confidential information in a place where the containers can
  access it.
* __Disk usage__: Disk usage limits are enforced by NTFS [disk
  quotas](https://technet.microsoft.com/en-us/library/cc938945.aspx#XSLTsection128121120120).
  Per-user disk quotas will apply to all files owned by a given user -- but
  because each container is run as a unique local user account, this is exactly
  what we’re looking for. This requires quotas to be enabled on the volume that
  contains the containerizer directory (C:\ by default). Quotas are currently
  enabled when running the setup.ps1 script included in the
  garden-windows-release distribution.
* __Network isolation__: applications launched inside a container bind directly to
  the external IP of the cell. Applications utilizing port mapping functions of
  the garden API must be adapted to map internal container ports to external
  ports.  See the
  [healthcheck](https://github.com/cloudfoundry/windows_app_lifecycle/blob/d627fe93d8c4ffb64e85e9a53939e60c32260b67/Healthcheck/Program.cs#L15-L20)
  or
  [diego-sshd](https://github.com/cloudfoundry-incubator/diego-ssh/blob/master/cmd/sshd/main_windows.go#L28-L35)
  for examples of how this works.
* __Memory usage__: To ensure that individual applications do not overrun their
  allocated memory limits, we utilize [Job
  Objects](https://msdn.microsoft.com/en-us/library/windows/desktop/ms684161.aspx).
  A job object may specify an upper bound on memory utilization of a group of
  processes. The operating system will not allow this limit to be exceeded.

Job objects’ memory limits are enforced by the Windows kernel. Additionally,
enforcement of memory limits is assisted by the
[Guard](https://github.com/cloudfoundry/IronFrame/blob/918b7fa248830b57288b91740e67f6a2532a2085/Guard/Guard.cpp).
The Guard polls for application memory usage and ensures that no application has
mapped more memory than allowed. If an application exceeds its memory limit, the
Guard will kill the offending job.

Additionally, if a process attempts to escape a Job Object, The Guard will stop
this rogue behavior and kill the process if needed. This ensures that memory
limits and job teardown can be enforced.

We at Pivotal believe that .NET is an important enterprise platform and are
committed to the success of the project. We’re also excited about future
opportunities for .NET on Cloud Foundry, including .NET Core and our [Steel
Toe](http://steeltoe.io/) initiative. Though the details of containerization on
Linux and Windows are currently different, the user experience is getting closer
and closer every day.

We hope that this serves as a good introduction to containers as they have been
implemented on Windows 2012. Our team is always available on
[Slack](https://cloudfoundry.slack.com/messages/greenhouse/) to answer any
questions you may have.
