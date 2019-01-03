---
authors:
- rowan
- cunnie
categories:
- Networking
date: 2018-11-28T17:16:22Z
draft: false
short: |
  How an elusive CI (Continuous Integration) error led us to uncover a hidden man-in-the-middle ssh proxy.
title: Troubleshooting Obscure OpenSSH Failures
---

## Abstract

By using tcpdump to troubleshoot an elusive error, we uncovered a
man-in-the-middle (MITM) ssh proxy installed by our information security
(InfoSec) team to harden/protect a set of machines which were accessible
from the internet. The ssh proxy in question was Palo Alto Network’s
(PAN) Layer 7 (i.e. it worked on any port, not solely ssh’s port 22)
proxy, and was discovered when we observed a failure to negotiate
ciphers during the ssh key exchange.

## The Problem

In our team's [Concourse CI] (continuous integration)
[pipelines](https://ci.nsx-t.cf-app.com/), we create new PCF [Pivotal Cloud
Foundry](https://en.wikipedia.org/wiki/Cloud_Foundry) environments, subject them
to a rigorous battery of tests, and then destroy them. Among our tests is the
[Container Networking
Acceptance](https://github.com/cloudfoundry/cf-networking-release/tree/develop/src/test/acceptance)
test suite (NATS or CNATS—not to be confused with the NATS messaging bus), which
runs many `cf ssh` commands to test app-to-app connectivity.

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/48293711-4366a480-e435-11e8-8d19-99d3b6aa0cb0.png" class="center" >}}

The error was elusive, but inconvenient — it would cause an entire test suite to fail.
Our only clue was a cryptic ssh failure:

```
Error opening SSH connection: ssh: handshake failed: EOF
```

Let's be clear: we're not using OpenSSH in our tests. Sure, we're using the SSH
protocol as implemented by the Golang library, but we're not using the command
line tool which so many of us know and love. In other words, we type `cf ssh`
instead of `ssh`.

The purpose of this [specialized
implementation](https://github.com/cloudfoundry/diego-ssh/blob/0f5b562e00a3ca52b0fa67527a43325aa743d401/cmd/ssh-proxy/main.go#L196)
of the OpenSSH protocol is to allow users of our Pivotal Application Service
(PAS) software to connect to their application, typically to debug.

Once again, though, it's not quite OpenSSH. For one thing, our server-side binds
to port 2222, not `sshd`'s 22. Also, it's written in Golang, not C (both the
client and the server).

## Defining the problem

The problem wasn't consistent. In fact, over the course of a 20-minute test
run, it would only appear once.

It didn't appear everywhere—one of our environments, maintained in San
Francisco, seemed immune to the problem. In fact, the problem reared its ugly
head only in our San Jose environments.

And, strangest of all, the problem only occurred on the first connection
attempt.  The first time `cf ssh` was run, it would fail, but subsequent
attempts succeeded.

We attempted connecting from workstations in Palo Alto, San Francisco, and Santa
Monica. The behavior remained consistent: the first attempt would fail, and the
remaining would succeed.

We tried using `ssh` as a client instead of `cf ssh`. Same behavior: first
would fail, remainder succeed.

We tried bringing up `sshd` as a server. The results surprised us: no failures.
Not one. Our `ssh-proxy` failed, but `sshd` didn't — what was going on?

We knew it was time for `tcpdump`. If we were going to get any further, we
needed to examine the raw packets.

## Using `tcpdump` on our Server

We ran `tcpdump` on our server (the "Diego Brain") to determine what
was happening during failed `cf ssh` connections. We discovered that, from the
Diego Brain's perspective, the user was shutting down the connection (by sending
a `FIN` packet).

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/49247572-9ead0680-f3e5-11e8-8952-c23f53106236.png" class="center" caption="From the standpoint of the Diego brain (192.168.2.6), the user (10.80.130.32) terminates (FIN) the session immediately after key exchange negotiation" >}}

We dug deeper — was there anything happening in the key exchange that caused the
connection to shut down?

Yes, there was something happening: the client and the Diego Brain could not
agree on a common set of ciphers.

These were the ciphers offered by the Diego Brain. Note that these ciphers are
the ones included in Golang's `ssh` package:

-   "curve25519-sha256@libssh.org"
-   "ecdh-sha2-nistp256"
-   "ecdh-sha2-nistp384"
-   "ecdh-sha2-nistp521"
-   "diffie-hellman-group14-sha1"
-   "diffie-hellman-group1-sha1"

These were the ciphers offered by the client:

-   "diffie-hellman-group-exchange-sha256"
-   "diffie-hellman-group-exchange-sha1"

We believe that the client shut down the connection because it could not agree
on a common cipher for key exchange. But the client and server were both written
in Golang, so their cipher suites should be identical. In fact, both Diffie
Hellman group exchange ciphers are [explicitly considered to be legacy
protocols](https://github.com/golang/go/issues/17230) by the Golang maintainers.
Why was the client's cipher suite different, and why did it include legacy
protocols?

At this point we also noticed that the SSH protocol was unexpected: it was
`SSH-2.0-PaloAltoNetworks_0.2`. We decided to trace the packets from the client.

## Using `tcpdump` on our Client

We ran `tcpdump` on our client, and attempted to connect (via `ssh`, not our
custom client, not `cf ssh`) to our Diego Brain. We found the unexpected SSH
protocol again, `SSH-2.0-PaloAltoNetworks_0.2`, but this time it was our Diego
Brain presenting it:

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/48366291-3aa6e600-e662-11e8-9cba-d6e4ea989245.png" class="center" caption="A packet trace of an two attempted connections to port 2222; the first failed, and the second succeeded." >}}

But the SSH protocol `SSH-2.0-PaloAltoNetworks_0.2` was _only presented when the
connection subsequently failed_. In the diagram above, we can see that the
ostensible Diego Brain shut down the connection by sending a FIN packet (packet
19) to our client.

## IOPS to the Rescue

We contacted IOPS, the Pivotal organization which maintains the network, who
explained that the  firewall is configured to **intercept and proxy all ssh
connections** originating from or terminating at the San Jose datacenter in
order to prevent ssh tunnel attacks, since the San Jose environments are
accessible from the internet.

## Our Conclusions

Our networking model was wrong:

{{< responsive-figure
src="https://docs.google.com/drawings/d/e/2PACX-1vQ91WlZe49wqBc6AdjYCFaUXF-A5pPrHsthVVDCeJPJOVBifhxUy3-8oQ6TNvAL10qbGKSSbpkFwf95/pub?w=1568&amp;h=1405"
class="center" caption="Unbeknownst to us, the Palo Alto Networks firewall was intercepting our ssh traffic." >}}

We concluded that our `cf ssh` connection *actually* works this way:

- Our firewall attempts to proxy all ssh connections to San Jose.
- When it attempts to contact the backend, it realizes it doesn't have a common cipher
  suite for key exchange, and can't establish a connection
- When it can't establish a connection with the server, it sends a FIN to the
  client (`EOF`)
- It proceeds to whitelist the client-IP, server-IP, server-port tuple for a
  little more than one hour <sup>[[timeout](#timeout)]</sup>. It does not attempt to proxy during that time
- It will attempt to proxy new client connections from different IP addresses
  during that time

Our final resolution to this issue was a workaround wherein each test suite that runs `cf ssh`, we "prime the pump" by running a `cf ssh` command, which we expect to fail, before running the test suite.

## Footnotes

<a id="timeout"><sup>[timeout]</sup></a>
The exact timeout is a little more than an hour, somewhere between 3720 and 3840
seconds.

We wrote a
[script](https://github.com/cunnie/bin/blob/c51fceac1a1af6361b4099957960958729e95046/pan_timeout.sh)
to more precisely determine the timeout. As can be seen from the output below
(edited for clarity), there was no proxy attempt at 3720 seconds (`Permission
denied...`), but there was at 3840 seconds (`Connection closed...`)

```
Permission denied (password).
Timeout: 3720
Connection closed by 10.195.84.17 port 2222
Timeout: 3840
```

## Corrections & Updates

*2019-01-02*

Include the amount of time that the PAN firewall waits after an unsuccessful
proxy attempt before triggering the next attempt.
