---
authors:
- ddieruf
categories:
- PASW
- .NET
- Windows
- stack
- cf
date: 2019-08-15T17:16:22Z
short: |
  Pivotal Application Service for Windows introduced the `-s windows` stack name in PASW 2.4, reducing the operator and developer need to concern themselves with specific Windows Server versions. From PASW 2.4 thru PASW 2.7, both the `windows2016` and `windows` stack names worked - giving sufficient time to migrate apps over to the new stack name.
title: Ensure Windows apps are using the `windows` stack before upgrading to PASW 2.8
image: 
---

Pivotal Application Service for Windows introduced the `-s windows` stack name in PASW 2.4, reducing the operator and developer need to concern themselves with specific Windows Server versions. From PASW 2.4 thru PASW 2.7, both the `windows2016` and `windows` stack names worked - giving sufficient time to migrate apps over to the new stack name.

Pivotal Application Service for Windows 2.8 will remove support for the deprecated `-s windows2016` stack name, requiring developers and operators to use the `-s windows` stack name. **Prior to upgrading to PASW 2.8, you MUST update any apps using the `windows2016` stack, to use the `windows` stack. Apps that are not updated to the `windows` stack WILL NOT START after upgrading to PASW 2.8.**

Operators can use the <a href="https://network.pivotal.io/products/buildpack-extensions" target="_blank">Stack Auditor CF CLI plugin</a> to get an inventory of all apps and their current stack, in a given foundation. They can also use the plugin to update an app stack to `windows` without needing access to the app’s source or automation pipeline. Be aware, changing the stack of an app WILL cause the app to restart which may lead to temporary downtime.

The plugin is available for download in the <a href="https://network.pivotal.io/products/buildpack-extensions" target="_blank">Buildpack Extensions</a> area of PivNet. Watch a video of running stack audit as well as upgrading apps, below. 

### Mandatory actions before upgrading to PASW 2.8

- [x] Find out which apps on your foundation are using the `-s windows2016` stack name, by using Stack Auditor `cf audit-stack` command
- [x] Use the Stack Auditor `cf change-stack` command to update all apps to use the `windows` stack
- [x] Update all app manifests and pipeline to specify the `windows` stack

<p align="center"><br />
  <a href="https://www.youtube.com/watch?v=jQLOztTjSFk" target="_blank"><img src="https://img.youtube.com/vi/jQLOztTjSFk/0.jpg" alt="video of running stack audit as well as upgrading apps" /></a>
<br /><br /></p>

### Links & Resources

- Download [Buildpack Extensions](https://network.pivotal.io/products/buildpack-extensions) (contains Stack Auditor)
- [PAS Windows 2.4 release notes](https://docs.pivotal.io/pivotalcf/2-4/pcf-release-notes/windows-rn.html#2.4.2) introducing `windows` stack
- [PAS Windows 2.5 release notes](https://docs.pivotal.io/pivotalcf/2-5/pcf-release-notes/windows-rn.html#windows2016) deprecating `windows2016` stack
- Documentation on [how to use the Stack Auditor plugin](https://docs.pivotal.io/pivotalcf/2-6/adminguide/stack-auditor.html)