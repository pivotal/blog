---
authors:
- aminjam
- sunjaybhatia
- ankeesler

categories:
- CF Runtime
- Diego
- Windows
- Containers
- .NET

date: 2018-03-12T11:25:15-04:00

draft: true

short: |
  Technical details for how we implemented containers on Windows Server Core 2016 for Pivotal
  Cloud Foundry.

title: "Windows Containers in Cloud Foundry? Here's How We Did It"
---

Hey, have you heard? Pivotal Cloud Foundry now supports running
applications in [Windows Server Containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/about/).

The platform has supported [.NET apps on Windows Server 2012 R2 for two years](http://engineering.pivotal.io/post/windows-containerization-deep-dive/).
This move is a significant step for .NET developers, continued to improve on the .NET developer
experience.

That effort got a huge boost with Windows Server 2016 and its native
support for [Windows Server Containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/about/).
"Native" is the key term; it enables a far more robust .NET developer experience
in Pivotal Cloud Foundry. Specifically, with native Windows Server Containers developers can:

- Use more platform features (compared to the earlier version based on 2012 R2)
- Enjoy improved isolation and resource management for their apps

We launched this effort months ago, and planned to support Windows Containers from
[Windows 1709 Fall Creators Update](https://blogs.windows.com/windowsexperience/2018/01/11/windows-10-fall-creators-update-1709-fully-available/).
And that’s just what we’ve done! Let’s take a closer look at how we 
engineered a mature platform like Cloud Foundry to support this new slant on containerization.

Garden-runC Release and Windows
-------------------------
Previously, for applications running on the windows2012R2 stack, the
garden-windows team implemented a Windows backend to the [garden API](https://code.cloudfoundry.org/garden)
and maintained [garden-windows-bosh-release](https://github.com/cloudfoundry-incubator/garden-windows-bosh-release).
(Long-time Cloud Foundry and .NET watchers will recall the Iron Foundry project. That’s the origin story for this tech).
This allowed the team to have flexibility and ownership of their own code
base. But, we felt some pains when integrating with new platform features.

We wanted to improve our development process when building our Garden implementation for
Windows Server 2016. So, we prioritized more cross-team collaboration with the core
Garden team. We also wanted to adopt the [OCI](https://www.opencontainers.org/)
standards for container lifecycle  and container image management. 
(We build to this standard for Linux on Cloud Foundry, so it makes sense to do this for Windows too).

To this end, we chose to integrate with [Garden-runC Release](https://code.cloudfoundry.org/garden-runc-release)
and [Guardian](https://code.cloudfoundry.org/guardian) rather than maintain
another BOSH release.

The pluggable nature of [Guardian](https://code.cloudfoundry.org/guardian) means we can
focus on solely implementing the Runtime, Network, and Image  plugins for Windows Server 2016:

- [__winc__](https://code.cloudfoundry.org/winc): the
OCI Runtime Plugin for creating and running containers in windows2016 stack.
- [__winc-network__](https://code.cloudfoundry.org/winc): the
Network Plugin for [Guardian](https://code.cloudfoundry.org/guardian).
- [__groot-windows__](https://code.cloudfoundry.org/groot-windows): the
Image Plugin for managing container images and setting up a root filesystem.
This plugin can be used with local OCI image or remote docker URIs.

Windows Container Isolation
---------------------------

Windows Server 2016 comes with Windows Server Containers. The primitives here
are similar to those Linux kernel. We use the official [hcsshim](https://github.com/Microsoft/hcsshim)
Go library for instrumenting the Windows Server Containers in Cloud Foundry. HCS
is the Windows Host Computer Service that performs the underlying container operation.
Windows Server Containers provide application isolation through process and namespace isolation technology.
A Windows Server container shares a kernel with the container host and all containers running on the host.

What about security? Here's how Garden-Windows secures applications:

- __Filesystem isolation__: By default, Windows Server Containers use a
  temporary scratch space on the system drive of the container host.
  This space is used for storage during the life of the container.
  This allows us to have a dedicated filesystem (e.g. Access to `C:\`) inside the container.
  Any modifications made to the container filesystem or registry are captured
  in a sandbox that's managed by the host. As a result, we are now able to create and
  maintain a root filesystem (rootfs) that allows applications to receive security upgrades when running on the platform.
<!-- -->
- __Disk usage__: Disk usage limits are enforced by NTFS
[disk quotas](https://technet.microsoft.com/en-us/library/cc938945.aspx#XSLTsection128121120120)
  in both windows2012R2 and windows2016 stack.
  Previously, this quota applied to all files owned by a given user.
  But, now with Windows Server Containers the quota is applied to the Sandbox image.
  (We used disk quotas because HCS currently doesn't have support for
  enforcing disk limits.)
<!-- -->
- __Network isolation__: Each Windows Server Container has a network compartment
that's analogous to Linux containers. Containers function similarly
to virtual machines in regards to networking. Each Container has a virtual network
adapter (vNIC) connected to a virtual switch. (Currently, we only support NAT 
driver mode.)
<!-- -->
- __Memory usage__: The Windows Host Compute Service (HCS) that manages Windows Server
Containers provides an API to set memory limits on containers at creation time.
<!-- -->
- __CPU usage__: Configuring CPU shares allocated to containers is now possible
in Windows Server Containers via the Windows Host Computer Service (HCS).

Future Work
-----------

There’s a .NET Renaissance underway, and we’re excited to be a part of it.
That’s why we’re continuing to contribute to the cloud-native .NET movement,
including .NET Core.

The best part? Native Windows Server Containers feature makes it easier for
us to add new capabilities. In the coming months, we plan to add support for
[Container-to-Container networking](https://docs.cloudfoundry.org/concepts/understand-cf-networking.html)
and [Volume Services](https://docs.cloudfoundry.org/devguide/services/using-vol-services.html)
for Windows Server Containers

We hope this post serves as a good introduction to containers as we've 
implemented on Windows Server 2016. What are your plans for .NET and Cloud Foundry?
We want to hear from you! Visit us on
[Slack](https://cloudfoundry.slack.com/messages/garden-windows/) and tell us
about your scenarios.
