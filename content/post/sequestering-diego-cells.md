---
authors:
- marie
categories:
- BOSH
- Cloud Foundry
- CF
- Operations
date: 2017-09-06T17:16:22Z
draft: true
short: |
  On Pivotal Web Services, we sometimes want to separate a few Diego cells out from the herd so we can keep them in a broken state for investigation and diagnosis. Learn about how we do it!
title: Sequestering Diego Cells
image: /images/not-a-real-image.jpg
---

## Sequestering Diego Cells

### Why?

Pivotal's Cloud Operations (CloudOps) team runs Pivotal Web Services (PWS), where we deploy bleeding-edge Cloud Foundry code. In addition to hosting many user apps, PWS is also a learning environment for the Cloud Foundry R&D teams. As part of this learning, sometimes we uncover interesting issues on PWS that Cloud Foundry R&D teams want to investigate. Since we're committed to providing a good experience for our users, we don't want to leave user apps in a bad state on PWS while R&D teams investigate, so we have strategies that allow us to investigate while minimally impacting user apps.

This post outlines our process for fully removing Diego cells from a Cloud Foundry deployment and BOSH management ("sequestering" the cells)  while still retaining our ability to connect to them for diagnosis of an issue. We developed this process to help the Diego team investigate an issue that is causing high load on some cells.

#### Wait, doesn't `bosh ignore` do that?

### Okay, how did you do it?

Buckle up, because this gets a little messy.

Here goes:
1. Set up a tmux or ssh session with the VM you're going to sequester
`tmux new-session -d -s investigate-cell/cell-id "ssh investigate@ip.of.cell -i investigate_key"`
2. Turn off resurrection for Diego cells
`bosh -e prod -d cf-cfapps-io2-diego update-resurrection off`
3. Kill bosh-agent
`sv down agent`
   a. Verify that SSH doesn't work any more and `bosh vms` shows "unresponsive agent"
4. Add cell IPs to the Diego manifest's reserved IPs section
5. `bosh cck` and choose `delete VM reference`
   a. Verify that `bosh vms` returns `-` for its status
6. *While resurrector is still disabled*, deploy the manifest with the reserved IPs so they don't get reallocated
7. Re-enable resurrection
8. Clear out apps you don't need (in case there are workers there that might be drawing down queues)

### Gotchas
Depending on the types of applications you're hosting on your Diego cell, the last step ("Clear out apps you don't need") may be pretty important. When we ran through this, we caused an interesting and mysterious bug where one Pivotal engineering team's requests were failing some of the time. This turned out to be because a worker on a sequestered cell was still pulling tasks from their queue, but wasn't able to complete them. If we'd only been running web apps on those cells, though, we would have been fine!