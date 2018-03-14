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
  Technical details for how we implemented containers on Windows 2016 Server Core for Pivotal
  Cloud Foundry.

title: "Implementing Windows Server Containers for Cloud Foundry : A Deep Dive"
---

Hey, have you heard? Pivotal Cloud Foundry now supports running
applications in [Windows Server Containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/about/).

The platform has supported [.NET apps on Windows 2012R2 for some time](http://engineering.pivotal.io/post/windows-containerization-deep-dive/)
and while this was a significant step for .NET developers, we wanted more feature
parity with Linux containers and to continue to improve on the .NET developer
experience.

In order to overcome some of the limitations of the Windows 2012R2 containerization
implementation, we looked to take advantage of Windows Server 2016 and its native
support for [Windows Server Containers](https://docs.microsoft.com/en-us/virtualization/windowscontainers/about/).
This exciting new technology enables us to give .NET developers a more first class
experience in PCF. We are able to integrate apps pushed to the Windows 2016 stack
with platform features that were not possible on Windows 2012R2. Developers can
now also rely on greatly improved isolation and resource management for their
apps.

The Semi-Annual release channel for Windows Server 2016 has a lot of
new improvements that we decided to start supporting Windows Containers from
[Windows 1709 Fall Creators Update](https://blogs.windows.com/windowsexperience/2018/01/11/windows-10-fall-creators-update-1709-fully-available/).

Garden-runC Release and Windows
-------------------------
Previously, for applications running on the Windows2012R2 stack, the
garden-windows team implemented a Windows backend to the [garden API](https://code.cloudfoundry.org/garden)
and maintained [garden-windows-bosh-release](https://github.com/cloudfoundry-incubator/garden-windows-bosh-release).
While this allowed the team to have flexibility and ownership of their own code
base, we felt some pains when integrating with new platform features.

To improve our development process when building our Garden implementation for
Windows 2016, we wanted to ensure more cross team collaboration with the core
Garden team. We also wanted to adopt the [OCI](https://www.opencontainers.org/)
standards for container lifecycle  and container image management. To do so, we
chose to integrate with [Garden-runC Release](https://code.cloudfoundry.org/garden-runc-release)
and [Guardian](https://code.cloudfoundry.org/guardian) rather than maintain
another BOSH release.

The pluggable nature of [Guardian](https://code.cloudfoundry.org/guardian) gives
us the ability to focus on solely implementing the Runtime, Network, and Image
plugins for windows2016.
- [__winc__](https://code.cloudfoundry.org/winc): This is the
OCI Runtime Plugin for creating and running containers in windows2016 stack.
- [__winc-network__](https://code.cloudfoundry.org/winc): This is the
Nework Plugin for [Guardian](https://code.cloudfoundry.org/guardian).
- [__groot-windows__](https://code.cloudfoundry.org/groot-windows): This is the
Image Plugin for managing container images and setting up a root filesystem.
This plugin can be used with local OCI image or remote Docker URIs.

Windows Container Isolation
---------------------------

Windows Server 2016 comes with Windows Server Containers, similar to the primitives
found in the Linux kernel. We use the official [hcsshim](https://github.com/Microsoft/hcsshim)
Go library for instrumenting the Windows Server Containers in Cloud Foundry. HCS
is the Windows Host Computer Service that performs the underlying container operation.
Windows Server Containers provide application isolation through process and namespace isolation technology.
A Windows Server container shares a kernel with the container host and all containers running on the host.

Here are some of the details on how Garden-Windows secures applications:

* __Filesystem isolation__: Windows Server Containers now by
default use a temporary scratch space on the container host's system drive for storage
during the lifetime of the container. This allows us to have a dedicated filesystem
(e.g. Access to `C:\`) inside of the container. Any modifications made to the
container filesystem or registry is captured in a sandbox managed by the host.
As a result, we are now able to create and maintain a root filesystem (rootfs) that allows
applications to receive security upgrades when running on the platform.

* __Disk usage__: Disk usage limits are enforced by NTFS [disk
  quotas](https://technet.microsoft.com/en-us/library/cc938945.aspx#XSLTsection128121120120)
  in both Window2012R2 and Window2016 stack.
  Previously, this quota applied to all files owned by a given user,
  but with Windows Server Containers the quota is now applied to the Sandbox image.
  We used disk quotas because HCS currently doesn't have support for
  enforcing disk limits.

* __Network isolation__: Windows Server Containers each have a network compartment
which is analogous to how the Linux containers work. Containers function similarly
to virtual machines in regards to networking. Each Container has a virtual network
adapter (vNIC) which is connected to a virtual switch. Currently, we only support *nat*
driver mode.

* __Memory usage__: The Windows Host Compute Service (HCS) that manages Windows Server
Containers provides an API to set memory limits on containers at creation time.

* __CPU usage__: Configuring CPU shares allocated to containers is now possible
in Windows Server 2016 through the windows Host Computer Service (HCS).


Future Work
-----------

We at Pivotal believe that .NET is an important enterprise platform and are
committed to the success of the project. We’re also excited about future
opportunities for .NET on Cloud Foundry, including .NET Core and our [Steel
Toe](http://steeltoe.io/) initiative. The user experience and adding new features
is so much better compared to our support for Windows 2012R2. In future, we are
working to add support for
[Container-to-Container networking](https://docs.cloudfoundry.org/concepts/understand-cf-networking.html)
and [Volume Services](https://docs.cloudfoundry.org/devguide/services/using-vol-services.html)
for Windows Server Containers

We hope that this serves as a good introduction to containers as they have been
implemented on Windows 2016. Our team is always available on
[Slack](https://cloudfoundry.slack.com/messages/garden-windows/) to answer any
questions you may have.
