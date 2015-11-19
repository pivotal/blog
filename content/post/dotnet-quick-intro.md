---
draft: true
categories: [".NET", "CF Runtime"]
authors:
- myoung
- jshahid
date: 2015-11-03T10:41:30-05:00
title: Deploying your first .NET app on Cloud Foundry
short: >
  PCF 1.6 brings with it support for .NET. Here's how to get started.
---

Cloud Foundry is a great platform for deploying your web applications. As of PCF 1.6, CF supports deploying .NET apps too!

Let's take a walk through deploying a simple .NET app to your existing Cloud Foundry.

## Prerequisites

* An existing Cloud Foundry installation with Elastic Runtime/Diego support. If you don't have one yet, first check out [Pivotal Cloud Foundry](http://pivotal.io/platform) or the [Cloud Foundry Open Source project](http://docs.cloudfoundry.org/deploying/).
* A Windows cell in your CF deployment using the latest compatible Diego Windows and Garden Windows MSIs. More information can be found in the [PCF docs](http://docs.pivotal.io/pivotalcf/opsguide/deploying-diego.html) or the [Diego Windows](https://github.com/cloudfoundry-incubator/diego-windows-release) and [Garden Windows](https://github.com/cloudfoundry-incubator/garden-windows-release) on GitHub.
* On your development machine:
  * Git. For Windows, we like [git for windows](https://git-for-windows.github.io/)
  * [Cloud Foundry CLI](https://github.com/cloudfoundry/cli)

## Deploying your first app

With that out of the way, now lets get to deploying. We'll start with a simple experimental app that you can just push.

1. First clone our basic sample app to a new directory:

        git clone https://github.com/cloudfoundry-incubator/.NET-sample-app.git my-app

    You can also download the source from the [GitHub page](https://github.com/cloudfoundry-incubator/.NET-sample-app)

1. If Diego is enabled by default on your CF deployment, you can just push your app and wait for it to start:

        cf push my-app -s windows2012R2 -b binary_buildpack -p ./my-app/ViewEnvironment/

1. If it's not, or if you're not sure, you'll need to install the [Diego Enabler](https://github.com/cloudfoundry-incubator/diego-enabler) CLI plugin and then enable Diego on the application before starting it:

        cf add-plugin-repo CF-Community http://plugins.cloudfoundry.org/
        cf install-plugin Diego-Enabler -r CF-Community
        cf push my-app -s windows2012R2 -b binary_buildpack --no-start -p ./my-app/ViewEnvironment/
        cf enable-diego my-app
        cf start my-app

1. Once your app is pushed, you can navigate to the app's URL and you will see all the VCAP variables.  Add `?all=` to the URL to see all the system variables too.

## General Debugging

If you have any errors, check your application logs:

        cf logs my-app --recent

## Next Steps

Cloud Foundry tries to simplify the process of deploying .NET apps. Try it with your own apps! Check your logs and report any issues on [GitHub](https://github.com/cloudfoundry-incubator/diego-windows-release).
