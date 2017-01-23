---
authors:
- mthomas
categories:
- Tomcat
- Security
- Migrated Context
date: 2011-04-25T06:30:00Z
short: |
  An overview of session fixation attacks and how they are prevented in Apache Tomcat.
title: Session Fixation Protection
---

A common practice these days in email marketing is to provide users with custom links that direct them quickly to their
own account, and streamline the number of steps needed to sign up for additional services or address outdated or
invalid account information. This is great for company relationships with their customers, however it is somewhat
easily exploited.

## A simple scenario

Mary and Bob both have accounts with the same bank. Mary is not very internet savvy, and Bob is. Bob sends Mary a link 
that is plainly seen to be their bank’s address and attaches a session ID:

```none
https://www.foobank.com/?SID=BOB_KNOWS_THE_ID
```

Mary sees its one of the bank’s URLs, and clicks it, logs in with her username and password. As soon as she does that,
Bob is able to also click that link and the session is now validated so he has full access to all her account
information and money!

There are more complex scenarios documented across the web. Some additional easy to understand examples can be found
on [Wikipedia](http://en.wikipedia.org/wiki/Session_fixation). Reality is that there are several things Mary could do
to be more educated and protect herself, but consumers are hard to educate perfectly. In turn, companies—especially
ones that rely on authenticated sessions to service their customers—must protect their customers from these types of
attacks.

## Session Fixation Protection

A new security feature for Apache Tomcat 7 is Session Fixation Protection. Essentially, when a user authenticates
their session, Tomcat will change the session ID. It does not destroy the previous session, rather it renames it so it
is no longer found by that ID. So in our example above, Bob would try and log on with that session, and he would not
be able to find it.

## Turning off Session Fixation Protection

Session fixation protection is turned on by default in all Apache Tomcat 7 versions and from Apache Tomcat 6.0.21 on.
If you do not wish to use this protection, you need to modify the configuration of the internal valve in Tomcat that
does the authentication.

Normally you do not see this valve in a `server.xml` or `context.xml` file. As soon as you configure a web application
with authentication, whether its basic, form, digest or client cert, Tomcat will automatically insert the appropriate
authentication valve into your configuration. To turn it off, rather than relying on Tomcat’s implicit configuration,
you will need to add it explicitly.

So, if you were using basic authentication, you would need to navigate to the `context.xml` file for your application
(not `$CATALINA_BASE/conf/context.xml` - that is the global `context.xml` that provides defaults for all web
applications) and add a valve using `className="org.apache.catalina.authenticator.BasicAuthenticator"` and also set
the parameter `changeSessionIdOnAuthentication="false"`.  For more information on the various valves and classes
needed, please see the Apache Tomcat Valve Configuration documentation.

## When to Disable Session Fixation

The ASF Security Team deemed this a basic enough protection to make it by default turned on in Tomcat 7. Turning it off is not generally advised, unless it is breaking your application functionality in some way. Generally, it is advised to leave this protection on as an added precaution for valuable customer information.
