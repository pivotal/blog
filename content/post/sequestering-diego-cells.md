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

This post outlines our process for fully removing Diego cells from a Cloud Foundry deployment and BOSH management ("sequestering" the cells) while still retaining our ability to connect to them for diagnosis of an issue. We developed this process to help the Diego team investigate an issue causing high load on some cells.

#### Wait, doesn't `bosh ignore` do that?

Lightly paraphrasing the BOSH documentation, `bosh ignore` tells the BOSH director to ignore an instance from being affected by other commands, such as `bosh deploy`. This is a useful feature, but there were a couple reasons why `bosh ignore` didn't work for our purposes.

First, `bosh ignore`-ing an instance doesn't have an effect on whether Diego uses that instance to allocate work, and the work that was already occurring on that instance will likely still continue. So, while BOSH will ignore the unhealthy instance, Diego will still see that instance as working.

Second, `bosh ignore` has a side-effect of not allowing deployments while there are `bosh ignore`d instances. That means that we were unable to deploy new Cloud Foundry code while this investigation was underway and we were using `bosh ignore`.

### Okay, how did you do it?

Buckle up, because this gets a little messy.

Here goes:
1. Set up a tmux (or SSH) session with the VM you're going to sequester.
`tmux new-session -d -s investigate-cell/[cell-id] "ssh investigate@[ip.of.cell] -i [investigate_key]"`
2. Turn off resurrection for Diego cells
`bosh -e prod -d diego-deployment update-resurrection off`
3. On the cell that you would like to sequester,
  a. `kill` the `route_emitter` process on the cell that you'd like to sequester (`ps aux | grep route_emitter` will help you find the appropriate PID to `kill`)
  b. Stop the `bosh-agent` with `sv down agent`
`sv down agent`
  c. Verify that SSHing into the sequestered instance no longer works
  d. Verify that `bosh vms` shows the status `unresponsive agent` for the appropriate VM.
5. Add the IP of the sequestered instance to the Diego manifest's reserved IPs section so that BOSH doesn't try to reuse that IP.
6. Tell BOSH to totally forget about the sequestered VM with `bosh cck`. Choose `delete VM reference`
   a. Verify that `bosh vms` returns `-` for the sequestered instance's status
7. *While BOSH resurrection is still disabled*, deploy the manifest with the reserved IP so it doesn't get reallocated
8. Re-enable resurrection
`bosh -e prod -d diego-deployment update-resurrection on`

#### But what about the applications that might still be running?
As mentioned previously, it's possible that applications on the sequestered instance could still be trying to do work. For example, a worker application might still be pulling work down from a queue and attempting to do it. It's so sad. Just lonely little robot applications, possibly trying to still do work. To clean up those applications, we'll need to SSH into the sequestered VM and delete the running containers. Retrieve the guids of the containers you'd like to keep for investigation
purposes, then use the following steps to delete the other running containers:

1. SSH into the sequestered VM 
`ssh investigate@[ip.of.cell] -i /root/investigate_key`
2. Retrieve the instance group for the container(s) you'd like to keep sequestered. The exact instructions for this step will depend on the reason your containers are failing. In our case, we retrieved the `pid` of the locked-up container and used it to get the instance group:
```
# cgroup=$(cat /proc/$pid/cgroup | grep memory | cut -d':' -f3); echo $cgroup
/dddd0000-0000-0000-0000-0000
# ig=${cgroup#/}; echo $ig
dddd0000-0000-0000-0000-0000
```
3. Since `garden` [stores each container in a subdirectory of "the depot,"](https://github.com/cloudfoundry/guardian/tree/master/rundmc) we can use `ls`, `xargs`, and `runc` to delete the no-longer-necessary containers:
```
# dry run
ls -1 /var/vcap/data/garden/depot | grep -v $ig | xargs -n1 -I {} echo /var/vcap/packages/runc/bin/runc delete {}
# actual container deletion
# ls -1 /var/vcap/data/garden/depot | grep -v $ig | xargs -n1 -I {} /var/vcap/packages/runc/bin/runc delete {}
```
4. We can check that the unnecessary containers got removed with `ls` again, where we can confirm that the only guids left are the ones that we wanted to keep:
`ls /var/vcap/data/garden/depot/*/processes`


### Gotchas

The sequestration process has been useful for debugging issues that are hard to track in a distributed system, but this also caused a couple hard-to-track issues by sequestering a cell in an incomplete way.

Depending on the types of applications you're hosting on your Diego cell, the last step ("Clear out apps you don't need") may be important. When we sequestered a cell, we caused an interesting and mysterious bug where one Pivotal engineering team's requests were failing, but only _some of the time_. We discovered that a background worker on a sequestered cell was still pulling tasks from the queue, but wasn't able to complete the tasks. This was the "lonely robot" problem mentioned above.
Following the steps in the "But what about the applications that might still be running?" section above will help solve this issue. 

We initially believed that the web applications on sequestered cells would no longer be responding to traffic. However, another issue was raised in which the CF routers were responding with `404` errors when a user was requesting an active app. In this case, a sequestered cell was still emitting route updates, but the application wasn't actually routable. The solution is to stop the `route_emitter` job on the sequestered cell(s), detailed in the sequestration process above.
