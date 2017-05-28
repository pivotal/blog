---
authors:
- jfullam
categories:
- Tomcat
- Continuous Integration
- Migrated Content
date: 2012-03-20T16:32:00+01:00
draft: false
short: |
  The practice of automated continuous deployment ensures that the latest checked in code is deployed, running, and accessible to various roles within an organization. You can start practicing continuous deployment very quickly using Tomcat or tc server, Jenkins, and your source control system of choice.
title: Integrating Jenkins and Apache Tomcat for Continuous Deployment
---

Working software is the primary measure of progress for software development teams. This is one of the principles of the [Agile Manifesto](http://www.agilemanifesto.org/principles.html) and has led agile software teams to focus on implementing the most important features of a system early and efficiently. These teams usually provide frequent deployments of the software in order to receive feature validation from the business and to show project progress. The benefits are quick and frequent feedback for the developers and congruous applications for the business.

The practice of automated continuous deployment ensures that the latest checked in code is deployed, running, and accessible to various roles within an organization. Project managers can have a place to check on project progress, testers have a view into the latest builds, developers can see the their modules working with the modules from other team members, and stakeholders can see how their requirements have been translated into working software. Tomcat and [tc server](https://network.pivotal.io/products/pivotal-tcserver) easily integrate with continuous integration servers to allow agile teams to realize continuous deployment while utilizing a lean application server (another practice of agile teams). You can start practicing continuous deployment very quickly using Tomcat or tc server, Jenkins, and your source control system of choice.

## Configuring Jenkins to Build Your Project

[Jenkins](http://jenkins-ci.org/) is a popular continuous integration server that is easy to install and configure. Installation is a simple as deploying the downloaded war file to your Tomcat webapps directory. The Jenkins interface is the accessed through a web browser. Assuming you have a JDK installed and you have a build tool already in place (ANT, Maven, etc), you can automate the building of your project in a few simple steps.

You will need to install a plugin to access your source control system. In my case, I used the [GIT Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Git+Plugin). You will also need a plugin that allows the interaction with Tomcat or tc Server from the command line. I use the [Post Build Task plugin](http://wiki.hudson-ci.org/display/HUDSON/Post+build+task) to allow me to execute a shell task after my build tasks have completed. Installing plugins is accomplished by accessing the “Manage Jenkins” page and choosing the “Manage Plugins” link. The plugins mentioned can be selected and installed from the list of available plugins.

Once Jenkins is installed and you have the necessary plugins enabled, you can create a new job and configure it to monitor your source control system. The first step is to point to your project in source control.

![source control configuration](/images/integrating-tomcat-jenkins/source-control.png)

The next step is to configure when Jenkins should build your project. This is accomplished by using a cron expression to specify the frequency of a build or how often to poll for changes in your source control system before building.

![build triggers configuration](/images/integrating-tomcat-jenkins/build-triggers.png)

In this case Jenkins will poll for changes in source control every 5 minutes. The frequency for building and deploying your application depends on who will be looking at the application. It could be sufficient to build the latest source every night, ensuring interested parties will have a fresh deployment to evaluate on a daily basis.

## Deployment with Apache Tomcat

The Tomcat manager application allows remote deployment to an instance of Tomcat. In this case, you need to configure Tomcat to allow access to the manager application through the plain text interface. This is accomplished by assigning the manager-script role to the credentials that will be performing deployments. This configuration depends on which Realm implementation you are using. The following example is utilizing the default MemoryRealm which reads an XML formatted file stored at `$CATALINA_BASE/conf/tomcat-users.xml`.

```xml
<tomcat-users>
    <user password="tomcat" roles=" manager-script" username="tomcat" />
</tomcat-users>
```
Next, you need to configure your job in Jenkins to utilize the manager interface in order to deploy your recently built application. This is configured using the Post Build task plugin.

![post build task plugin configuration](/images/integrating-tomcat-jenkins/post-build-task-plugin.png)

You can use wget, curl, or a similar tool to call the manager HTTP interface. It is necessary to first undeploy the application before deploying the new build. This avoids issues with deploying to an existing context path. The location of the newly built application war file can be determined by examining the output from a previous Jenkins job execution for that job.

```
wget "http://tomcat:password@localhost:8080/manager/text/undeploy?path=/spring-travel" -O - -q
wget "http://tomcat:password@localhost:8080/manager/text/deploy?path=/spring-
   travel&war=file:<path to="" war="">" -O - -q
</path>
```

## Deployment to tc Server

Often times, an application needs to be deployed across several different environments. This could be because the application is clustered, there are dedicated instances for dedicated teams, or there is a need to test the application on different platforms. VMware vFabric tc Server provides centralized management and monitoring of server instances and groups of instances through its built in integration with [vFabric Hyperici](http://www.hyperic.com/?p=tcserver&lp=1&cid=70180000000wVJj&cid=70170000000XDJI). The following steps assume you’ve installed the Hyperic server and a Hyperic agent is installed on the machines containing tc Server.

To group instances of tc server together, click the Resources > Browse link located at the top of the Hyperic web interface. You then select the tc server resources you’d like to group and click on the group button.

![resources configuration](/images/integrating-tomcat-jenkins/resources.png)

Once you have a group defined, you can let Hyperic manage the deployment of your application to a single or group of tc Server instances.

To access the tc Server management capabilities from Jenkins (and the command line), you need to download and configure the tcsadmin interface from Hyperic. This is available for download from your Hyperic server under the Administration tab. You will need to download and unzip this file on the same server that is running your Jenkins CI server. You can optionally add the tcsadmin.sh or tcsadmin.bat script to your system PATH.

![CI plugin in configuration](/images/integrating-tomcat-jenkins/ci-plugin-cli.png)

In order for tcsadmin to communicate with the Hyperic server, you need to provide the commands with server location and credentials. To avoid including the credentials in the Jenkins job configuration, specify connections parameters in a file called client.properties in a .hq sub-directory of the home directory of the user running Jenkins.

```
host=hq-server
 port=7080
 user=tcserver-admin
 password=secret-password
```

Replace the Tomcat manager calls in the Jenkins job configuration with calls to tcsadmin.sh.

```bash
tcsadmin.sh undeploy-application --groupname=spring-travel-group --application=spring-travel
```

```bash
tcsadmin.sh deploy-application --groupname=spring-travel-group --localpath=<path to="" war=""> 
    --contextpath=spring-travel</path>
```

Using the tcsadmin interface allows you to configure a job in Jenkins once without the need to make modifications when changing or adding servers to the group targeted for continuous deployment.

## Conclusion

It is important to note that there are other ways to accomplish continuous deployment using these technologies. For example, you could have the deployment triggered from your ANT or Maven based build tools and use Jenkins purely for triggering the build. The important point is that agile teams typically gravitate towards lean runtimes such as Tomcat and tc Server for their java applications and the benefits of continuous deployment can be easily integrated into these lean runtimes utilizing popular tools for building software, continuous integration, and source control.
