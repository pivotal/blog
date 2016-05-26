---
authors:
- mthomas
categories:
- Security
- Java
- Apache Tomcat
- Pivotal tc Server
date: 2016-05-24T15:00:00+01:00
short: |
  If you use remote JMX, you need to update your JVM to address CVE-2016-3427
title: Java Deserialization, JMX and CVE-2016-3427
---

## Background
As the [Pivotal Security Team](https://pivotal.io/security) lead and a member of the [Apache Software Foundation (ASF) Security Team](https://www.apache.org/security), I review a steady stream of security vulnerability reports across a wide range of products. From time to time a particular vulnerability, or class of vulnerabilities, attracts the interest of the security research community and we see a noticeable spike in related vulnerability reports. Last November, the focus was pointed squarely at Java deserialization.

Java serialization turns a Java object or group of objects into a stream of bytes (e.g. for sending over a network). Java deserialization performs the inverse action and turns a stream of bytes back into one or more Java objects. The risks associated with Java deserialization are not new. For example, early in 2013 Pierre Ernst wrote a [nice article](http://www.ibm.com/developerworks/java/library/se-lookahead/index.html) describing the risks and explaining how to mitigate them. Two years later Gabriel Lawrence and Chris Frohoff presented [“Marshalling Pickles”](http://frohoff.github.io/appseccali-marshalling-pickles/) at AppSecCali which went further and introduced a tool, [ysoserial](https://github.com/frohoff/ysoserial), to generate malicious payloads to test Java deserialization endpoints. And in November last year, Stephen Breen of FoxGlove security used ysoserial to [demonstrate](http://foxglovesecurity.com/2015/11/06/what-do-weblogic-websphere-jboss-jenkins-opennms-and-your-application-have-in-common-this-vulnerability/) that a number of well-known and widely used commercial and open source products were vulnerable to attack via Java deserialization. This blog post attracted a lot of attention and resulted in multiple vulnerability reports being raised against both Pivotal and ASF projects.

The majority of vulnerability reports received by Pivotal and the ASF were related to ysoserial’s use of Pivotal and ASF products to exploit Java deserialization vulnerabilities. These reports missed a fundamental point. The root cause when an application is vulnerable via Java deserialization is not in the library that the attack leverages to deliver the payload, but in the application that blindly deserializes data from an untrusted source without validation or sanitization. Many of the reports were, therefore, rejected but amongst the reports there were a handful of valid issues that were addressed.

## Apache Tomcat vulnerabilities
The majority of my time is spent working as a committer on the Apache Tomcat project. Having seen that a large numbers of products had made security errors around Java deserialization, I naturally began to wonder if we in the Apache Tomcat community had made similar mistakes. An audit of the Tomcat codebase quickly highlighted a number of areas where Java deserialization was used. These were all related to session persistence and/or replication. For most users, this did not present a security issue. The only way a malicious object could be deserialized was if an application placed it there and, for the vast majority of users, applications are trusted.

There are, however, a small minority of users where applications are not trusted. These are typically hosting environments where the Java SecurityManager is used to ensure that applications are restricted in what they can do. In this scenario, a malicious application could place a malicious object into the session and then wait for it to be deserialized (e.g. on a Tomcat restart). Tomcat handles Java deserialization of session data internally, which means the restrictions applied by the SecurityManager to web applications do not apply. Therefore, this offered a mechanism to bypass the restrictions of the SecurityManager. This issue is CVE-2016-0714 and was fixed in all currently supported Tomcat versions.

At the same time as CVE-2016-0714 was being addressed, I started to wonder if the root cause of any previous deserialization vulnerabilities had been incorrectly analysed. I therefore undertook a review of those issues and I found CVE-2013-4444. (Interestingly this was reported by Pierre Ernst who wrote the [IBM article](http://www.ibm.com/developerworks/java/library/se-lookahead/index.html) I mentioned earlier that discussed the risks inherent in Java deserialization). In hindsight, this was a classic case of fixing the symptom rather than the cause. That a malicious DiskFileItem instance could enable remote code execution was not the fault of DiskFileItem but of the mechanism that was blindly allowing deserialization of data from an untrusted source. I could have kicked myself for missing this the first time around but at least I had found it first.

## Java Runtime vulnerabilities
As I started to dig into the true root cause of CVE-2013-4444 I realised that I had stumbled over a significant vulnerability. I tracked down the root cause to the authentication mechanism used by JMX when configured for remote access. JMX utilises RMI and the username and password are passed as a String[] in serialized form. The root cause of CVE-2013-4444 was that this user name and password were deserialized without any validation that the serialized data represented a String array. Therefore, an attacker could pass any serialized Java object and have the remote JVM deserialize it. When combined with ysoserial, an attacker had the potential to trigger remote code execution on any JVM exposing JMX to remote systems.

While not vulnerable to this attack by default, Tomcat would be vulnerable when using the RemoteJmxLifecycleListener. I therefore spent some time exploring options for a work-around. It is possible to configure RMI to use a custom ServerSocketFactory. It is therefore possible to wrap the Sockets and in turn the InputStreams it produces and apply filtering. I made some progress with this but getting the filtering exactly right was difficult. I had something that looked as if it mostly worked but ‘mostly worked’ really isn’t want you want when protecting against a security vulnerability, especially one that enables remote code execution. More time and finding some more detailed documentation on the protocol being used might have enabled a robust work-around to be found.

In parallel to my investigation of a work-around, I reported this vulnerability to the Oracle Security Team. My hope was that they would accept the report and produce a fix. I did not relish trying to develop my prototype workaround to the point where it could be added to the Tomcat code base. Fortunately, Oracle did accept my report and - over the following months - produced a fix. The issue is now known as [CVE-2016-3427](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2016-3427) and was fixed as part of the [April 2016 critical patch update](http://www.oracle.com/technetwork/topics/security/cpuapr2016-2881694.html) ([advisory](http://www.oracle.com/technetwork/security-advisory/cpuapr2016v3-2985753.html)) where it attracts a CVSS risk score of 9.0 (v3) or 10.0 (v2) depending on which CVSS version you use.

## Conclusion
The one mitigating factor for CVE-2016-3427 is that it also requires a suitable class to leverage to exist on the classpath. However, security researchers continue to identify new ways to leverage serialization attacks so I would strongly encourage anyone using remote JMX to update their Java Runtime Environment to one that includes a fix for CVE-2016-3427 as soon as possible.

## Afterthoughts on timing
I often see folks wondering how long this sort of process typically takes so I offer the timings for this issue as a data point. Based on my experience at both Pivotal and the ASF, the timescales do not seem atypical.

* 2015-11-17 Initial report to Oracle
* 2015-11-20 Oracle acknowledge receipt
* 2015-12-02 Confirmation from Oracle
* 2016-03-24 Issue fixed in mainline code
* 2016-04-15 Advance notice from Oracle of release date
* 2016-04-19 Fix released
