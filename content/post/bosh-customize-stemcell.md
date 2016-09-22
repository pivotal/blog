---
authors:
- cunnie
categories:
- BOSH
date: 2016-09-21T05:35:01-07:00
draft: true
short: |
  BOSH Stemcells are Linux-based bootable disk images upon which BOSH applications
  may be deployed. This blog post describes a process to customize a
  stemcell (most often used to troubleshoot stemcell boot problems).
title: How to Customize a BOSH Stemcell
---

In this blog post, we describe the procedure we followed in order to create a
custom Google Compute Engine (GCE) stemcell with a user `cunnie` whose
`~/.ssh/authorized_keys` is pre-populated with a specific public key.

<div class="alert alert-info" role="alert">

This blog post describes <i>customizing</i> a stemcell, not <i>building</i> a
stemcell from scratch. The BOSH GitHub repository has an <a class="alert-link"
href="https://github.com/cloudfoundry/bosh/tree/4115bef082722ec24d69d41d0deb54017679c94c/bosh-stemcell">excellent
description</a> of the procedure to <i>build</i> a stemcell.

</div>

## 0. Download the Stemcell to Customize

We need to make our changes from a Linux machine (macOS can not mount Linux
filesystems as a loopback device). <sup><a href="#macos_mount" class="alert-link">[macOS mount]</a></sup>

We repurpose our [BOSH Lite](https://github.com/cloudfoundry/bosh-lite) Director
as a stemcell-building VM (BOSH Lite is already installed on our macOS
workstation, it has mounted our macOS's filesystem under `/vagrant` (simplifies
stemcell transfer and eliminates running-out-of-space issues), and using it to
build our stemcell in no way impedes its ability to perform as a BOSH Director).

```bash
  # we use the BOSH Lite directory as a staging point
cd ~/workspace/bosh-lite
 # download the stemcell:
curl -L https://bosh.io/d/stemcells/bosh-google-kvm-ubuntu-trusty-go_agent?v=3263.2 -o tmp/custom_stemcell_3263.2.tgz
```

<div class="alert alert-warning" role="alert">

<b>Don't download "Light" stemcells</b>. Certain IaaSes (e.g. Amazon Web
Services (AWS)) have "Light" stemcells as well as "Regular" stemcells, but
"Light" stemcells aren't true stemcells (i.e. they don't contain a bootable disk
image); instead they are pointers to the actual stemcell (in Amazon's case, a
list of Amazon Machine Images (AMIs) by region). Always be sure to download the
regular stemcell. Light stemcells are small, typically ~8kB; Regular stemcells
are large, typically ~600MB. On <a class="alert-link"
href="http://bosh.io/">bosh.io</a>, a light stemcell will be denoted with the
word "Light" (e.g. "AWS Xen-HVM Light")

</div>

## 1. Use BOSH Lite to Modify stemcell

```bash
 # bring up BOSH Lite (if it isn't already running):
vagrant up
vagrant ssh
 # we are now in a Linux box; we will customize our stemcell here:
 # create our mountpoint
sudo mkdir /mnt/stemcell
cd /vagrant/tmp
mkdir stemcell image
cd stemcell
 # unpack the stemcell:
tar xvf ../custom_stemcell_3263.2.tgz
cd ../image
 # unpack the bootable Linux disk image
tar xvf ../stemcell/image
 # connect the bootable Linux disk image to a loopback device
sudo losetup /dev/loop0 disk.raw
 # probe for the new partitions
sudo partprobe /dev/loop0
 # mount the disk image
sudo mount /dev/loop0p1 /mnt/stemcell
 # we like to use chroot to avoid accidentally polluting the BOSH Lite filesystem
sudo chroot /mnt/stemcell /bin/bash
 # we create user 'cunnie' in the 'admin' group (sudo), passwd `c1oudc0w`
useradd -m -G admin -p $(openssl passwd -1 -salt xyz c1oudc0w) cunnie
 # change to the new user's homedir
cd ~cunnie
 # we create the directory
mkdir .ssh
 # install the public key
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9An3FOF/vUnEA2VkaYHoACjbmk3G4yAHE3lXnGpIhz3EV5k4B5RzEFKZnAIFcX18eBjYQIN9xQO0L9xkhlCyrQHrnXBjCDwt/BuQSiRvp3tlx9g0tGyuuJRI5n656Shc7w/g4UbrQWUBdLKjxTT4kTgAdK+1pgDbhAXdPtMwt4D/sz5OEFdf5O5Cp+0spxC+Ctdb94taZhScqB4xt6dRl7bwI28vZdq6Sjg/hbMBbTXzSJ17+ql8LJtXiUHO5W7MwNtKdZmlglOUy3CEIwDz3FdI9zKEfnfpfosp/hu+07/8Y02+U/fsjQyJy8ZCSsGY2e2XpvNNVj/3mnj8fP5cX cunnie@nono.io' > .ssh/authorized_keys
 # set ownerships and permissions
chmod 700 .ssh
chmod 600 .ssh/authorized_keys
chown -R cunnie:cunnie .ssh
 # we're done, hop back to our "normal" BOSH Lite root filesystem
exit
 # unmount our filesystem
sudo umount /mnt/stemcell
 # delete our loop device
sudo losetup -d /dev/loop0
 # tar up our modified Linux bootable disk image
tar czvf ../stemcell/image *
 # change back to our stemcell directory
cd ../stemcell
 # update the manifest to use a new stemcell number
vi stemcell.MF
```

We find it good practice to modify the stemcell number when customizing a
stemcell — it prevents many kinds of errors, and well worth the additional time
spent  re-compiling BOSH releases. In this example, we bump the stemcell number
to `3263.2.1`:

```diff
-version: '3263.2'
+version: '3263.2.1'
bosh_protocol: 1
sha1: 6dec63560e5ee516e8495eeb39553e81049e19b8
operating_system: ubuntu-trusty
cloud_properties:
  name: bosh-google-kvm-ubuntu-trusty-go_agent
-  version: '3263.2'
+  version: '3263.2.1'
```

We create our new, custom stemcell; we put the new version number in the name:

```bash
 # create the stemcell
tar czvf ../custom_stemcell_3263.2.1.tgz *
 # exit the Vagrant ssh session
exit
```

## 2. Use the New Stemcell

We upload our new stemcell to our director, which takes ~6 minutes.

```bash
 # we upload the stemcell to our BOSH Director
bosh upload-stemcell ~/workspace/bosh-lite/tmp/custom_stemcell_3263.2.1.tgz
```





---

## Footnotes

<a name="macos_mount"><sup>[macOS mount]</sup></a> We would be interested if
someone has mounted a Linux filesystem to a macOS machine using a loopback
device. If the procedure is not too burdensome, we may include it in our blog
post.
