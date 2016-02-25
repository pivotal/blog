---
authors:
- mikegehard
categories:
- Concourse
date: 2016-01-13T13:59:00-07:00
draft: false
short: |
  You need to debug your Concourse ATC server. How do you turn up the logging level to allow that?
title: Concourse Web Logging
---

This morning a member of my team was having trouble logging into our Concourse web UI (aka ATC).
When I ssh'd into the VM, I noticed that the logging wasn't showing anything useful. Thanks to the
helpful folks in the [Concourse Slack room](http://slack.concourse.ci/), I was able to come up with a
set of curl commands that allows you to set the logging level via the API.

~~~bash
$ curl "http://my-concourse-server.com/api/v1/log-level"
info
$ curl -X PUT -H "Authorization: Bearer my-big-long-oauth-token" -d "debug" "http://my-concourse-server.com/api/v1/log-level"
$ curl "http://my-concourse-server.com/api/v1/log-level"
debug
~~~

We happen to be using GitHub authentication that necessitates the need for the Authorization header. You can get the value
for `my-big-long-oauth-token` from your `~/.flyrc` file. Make sure you have logged in lately via `fly login` so you have a fresh token.

If you are using basic authentication, you can use the following curl command.

~~~bash
$ curl --user name:password -X PUT -d "debug" "http://my-concourse-server.com/api/v1/log-level"
~~~
