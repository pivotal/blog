---
draft: false
categories: [".NET", "CF Runtime"]
authors:
- myoung
- jshahid
date: 2016-01-13T10:00:00-05:00
title: Deploying your first .NET app on Cloud Foundry
short: >
  PCF 1.6 brings with it support for .NET. Here's how to get started.
---

We on the .NET team for Cloud Foundry are pretty excited about our recently released support for .NET applications in CF! As of November 2015, this 1.0 support for Windows applications is available with Pivotal Cloud Foundry (PCF) 1.6, and is completely open source and available within the [Cloud Foundry Foundation] (https://www.cloudfoundry.org/).

Finally, Windows developers will have access to the magic of Cloud Foundry!

We're really excited to bring the magic of Cloud Foundry to Windows developers as well!

## Some Background
Cloud Foundry is a great platform for deploying your web applications. Once you've set it up, the experience as a developer is as easy as `cf push` to push your app live to the platform.

You may have heard about the recent [_Diego_](https://docs.cloudfoundry.org/concepts/diego/diego-architecture.html) effort within CF. If not, Onsi has a great primer [here](https://blog.pivotal.io/pivotal-cloud-foundry/features/cf-summit-video-diego-reimagines-the-cloud-foundry-elastic-runtime). At a high level though, Diego is the new _runtime_ for CF.

In order to get .NET applications to run on a Windows Server, we needed to implement:

* Diego support for Windows
* Garden container support for Windows*

	*_PS. This is where we got the name of the project. Garden + Windows = Greenhouse!_
	
Over the past several months, we've spent a lot of time implementing both of these on top of Windows 2012 R2, and we now _fully support_ Diego on Windows! You can see all of our code on Github in [Diego Windows](https://github.com/cloudfoundry-incubator/diego-windows-release) and [Garden Windows](https://github.com/cloudfoundry-incubator/garden-windows).

Now that we're all set with the background, lets actually deploy an app!

## Prerequisites for Deploying Windows Apps

* An existing Cloud Foundry installation with Elastic Runtime/Diego support. If you don't have one yet, first check out [Pivotal Cloud Foundry](http://pivotal.io/platform) or the [Cloud Foundry Open Source project](http://docs.cloudfoundry.org/deploying/).
* At least one Windows cell in your CF deployment using the latest compatible Diego Windows and Garden Windows MSIs. More information can be found in the [PCF docs](http://docs.pivotal.io/pivotalcf/opsguide/deploying-diego.html) or the [Diego Windows Install Instructions](https://github.com/cloudfoundry-incubator/diego-windows-release/blob/master/docs/INSTALL.md) on Github
* On your development machine (_Windows machine not required if you're using our pre-built sample app_):
  * Git. For Windows, we like [git for windows](https://git-for-windows.github.io/)
  * The latest [Cloud Foundry CLI](https://github.com/cloudfoundry/cli)

## Deploying your first app

With that out of the way, now lets get to deploying. We'll start with a simple sample app that you can just push. You can follow these instructions on either a Linux or a Windows client machine.

1. First clone our basic sample app to a new directory:

    ``` bash
    $ git clone https://github.com/cloudfoundry-incubator/NET-sample-app.git
    ```

    You can also download the source from the [GitHub page](https://github.com/cloudfoundry-incubator/.NET-sample-app)

1. If _Diego is enabled by default_ on your CF deployment, you can just push your app and wait for it to start:

    ``` bash
    $ cf push my-app -s windows2012R2 -b binary_buildpack -p ./my-app/ViewEnvironment/
    ```

   This is telling CF to push your app with the name `my-app`, using the **stack** `windows2012R2`, with the **buildpack** `binary_buildpack` from the **path** of `./my-app/ViewEnvironment/`.

1. If it's not, or if you're not sure, you'll need to install the [Diego Enabler](https://github.com/cloudfoundry-incubator/diego-enabler) CLI plugin and then enable Diego onn the application before starting it:

    ``` bash
    $ cf add-plugin-repo CF-Community http://plugins.cloudfoundry.org/
    $ cf install-plugin Diego-Enabler -r CF-Community
    $ cf push my-app -s windows2012R2 -b binary_buildpack -p --no-start ./my-app/ViewEnvironment/
    $ cf enable-diego my-app
    $ cf start my-app
    ```

1. Once your app is pushed, you can navigate to the app's URL and you will see all the VCAP variables.  Add `?all=` to the URL to see all the system variables too.

### Some Notes:
For Windows applications, we rely on the *binary_buildpack* to push pre-compiled applications. If you want to push your own app, make sure to build it locally and push those compiled binaries, as opposed to the uncompiled source files like you might do on a Linux host.


If you have any errors, check your application logs:

``` bash
$ cf logs my-app --recent
```

In general, once you've built an application in Visual Studio, you'll want to publish the application in VS (see [MSDN instructions](https://msdn.microsoft.com/library/1y1404zt(v=vs.100).aspx)) and then push the folder that you've published to, and not the root folder for your app.

## Next Steps

Cloud Foundry simplifies the process of deploying .NET apps. Try it with your own apps! Check your logs and report any issues to us on [GitHub](https://github.com/cloudfoundry-incubator/diego-windows-release), or on the **#Greenhouse** channel on the open [Cloud Foundry Slack](http://slack.cloudfoundry.org/).
