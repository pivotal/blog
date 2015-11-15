---
draft: true
categories: [".NET", "CF Runtime"]
authors:
- myoung
- jshahid
date: 2015-11-03T10:41:30-05:00
short: >
  Deploying your first .NET app on Cloud Foundry
---

Cloud Foundry is a great platform for deploying all of your web applications. Did you know that includes many of your .NET apps too?

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

1. Push your app and wait for it to start:

        cf push my-app -s windows2012R2 -b binary_buildpack -p ./my-app/ViewEnvironment/

1. Now direct your browser to http://my-app.your-domain and you'll see the app's environment details.


## Debugging: Enabling Diego

If you get this error, then you will need to enable diego


		Starting app my-app in org ORG / space SPACE as admin...
		FAILED
		Server error, status code: 404, error code: 250003, message: The stack could not be found: The requested app stack windows2012R2 is not available on this system.

1. Install the Diego-enabler plugin:

  * [CF Diego Enabler Plugin](https://github.com/cloudfoundry-incubator/Diego-Enabler)

1. Enable diego for your app:

        cf enable-diego my-app

1. Then restart:

        cf restart my-app

## General Debugging

If you still have errors, check our application logs

1. To follow your app's logs use:

        cf logs my-app --recent

## Next Steps

Cloud Foundry tries to simplify the process of deploying .NET apps. Try it with your own apps! Check your logs and report any issues on [GitHub](https://github.com/cloudfoundry-incubator/diego-windows-release).