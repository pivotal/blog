---
authors:
- angela
- clay
- grosenhouse
- utako
categories:
- Networking
- Routing
- Cloud Foundry
- Keep-Alives
- Debugging
- TCP
date: 2018-11-01T17:16:22Z
short: |
  Let's journey through a debugging session to understand best practices in configuring the Cloud Foundry deployment's networking stack, debug interacting keep-alive timeouts, and get familiar with the TCP layer.
title: Understanding Keep-Alive Timeouts in the Cloud Foundry Networking Stack
---

## Introduction

Setting up ingress routing is hard. Debugging problems when the routing tier is misconfigured can be even more challenging. At Pivotal, we often run into these types of issues. Below, we examine one such debugging session to understand both best practices in configuration and debugging.

## The Problem

The customer has two microservices deployed. The user's browser drives one microservice, which we’ll call Frontend Microservice. When called from the browser, Frontend Microservice sends CRUD requests to another microservice, which we’ll call Backend Microservice. 

The error occurs when Frontend Microservice sends one GET and then a PUT immediately afterward. The PUT errors with a 500 status code and the following error: 

~~~
[Request processing failed; nested exception is org.springframework.web.client.ResourceAccessException: I/O error on PUT request for "https:/example.com/example-service": Unexpected end of file from server; nested exception is java.net.SocketException: Unexpected end of file from server] with root cause
~~~

Oddly enough, if five seconds or more elapse between the GET and the PUT, then the PUT succeeds.


## The Networking Setup

{{< responsive-figure src="/images/understanding_keep_alive_timeouts/networking_setup.jpg" class="center" >}}

* The two Spring framework microservices (Frontend Microservice and Backend Microservice) are hosted within the same Cloud Foundry deployment.
* An external load balancer is configured to forward traffic to a BOSH-deployed HAProxy. The HAProxy forwards traffic to the Cloud Foundry GoRouter, and the GoRouter to the microservices.
* The call from Frontend Microservice to Backend Microservice follows the same path.
* At each layer of this networking stack, components are configured differently; e.g. keep-alive timeouts.


## Finding the Root Cause

### Drawing a Diagram

We started out by drawing a diagram of the deployment topology, shown above. This enabled us to have a shared and clear understanding of how networking traffic was flowing between the components and apps, and even helped us rectify some misunderstandings we originally had about the system.

### Cross-Referencing the Logs

We observed that there were no logs on the GoRouter for the PUT request, and narrowed the scope of our investigation to understanding what was happening with traffic between Frontend Microservice and HAProxy. 

{{< responsive-figure src="/images/understanding_keep_alive_timeouts/cross_referencing_the_logs.jpg" class="center" >}}

### Understanding the TCP Trace

We then cross-referenced TCP traces run on the HAProxy with component and app logs to follow the traffic through the deployment topology. Our reading of this specific trace is as follows:

{{< responsive-figure src="/images/understanding_keep_alive_timeouts/tcp_trace.png" class="center" alt="julia evans writes cool zines about networking" >}}

10.167.208.12:443 is an HAProxy, doing TLS termination and forwarding to CF GoRouters. The packets were captured from this VM. 10.167.212.38:44584 is the HTTPS client Frontend Microservice, running on a Diego Cell


| TCP Trace | Additional Observations |
| ----------| ----------------------- |
| 25 & 26: Frontend Microservice makes an HTTPS request (via Load Balancer) to the HAProxy | Frontend Microservice logs show a GET request |
| 27 & 28: HAProxy acknowledges the request, and sends the HTTPS response | Frontend Microservice logs show 200 OK |
| 29: Host running Frontend Microservice acknowledges the HTTPS response | |
| | *0.5 seconds elapse without any traffic* |
| 30 & 31: HAProxy closes the TLS session and closes the TCP stream | Consistent with their HAProxy config timeout http-keep-alive 500ms |
| 32 & 33: Host running Frontend Microservice acknowledges the closed TLS session and closed TCP stream | |
| | *2.8 seconds elapse without any traffic* |
| 34 - 42 even numbers: Frontend Microservice sends another HTTPS request on the same TCP stream! | Frontend Microservice logs show a PUT |
| 44, 46: Frontend Microservice closes the TLS session and TCP stream | Frontend Microservice logs show it got a TCP EOF while reading the HTTP response |
| 35 - 47 odd numbers: HAProxy responds with RST to all the recent Frontend Microservice packets | As it should, since the HAProxy previously closed the TCP stream |

We observed odd app behavior in packets 32-42 of the TCP trace. To reiterate, Frontend Microservice acknowledges the HAProxy closing the TLS session and TCP stream (packets 32 and 33). Despite this acknowledgment, Frontend Microservice sends another request on the same TCP stream (even numbers in packets 34-42).


### Getting Help and Completing the Picture

At this point, we needed to crowdsource some Spring and TCP expertise from the rest of the Pivotal organization. This brought the issue to the attention of Spring framework experts, who informed us of Spring’s default keep-alive timeout of 5 seconds. So, at this point, we knew that 5 seconds after an initial connection was established, Frontend Microservice would create a new connection, resulting in successful requests.

So, why did HAProxy close the connection with Frontend Microservice? The HAProxy was configured with a keep-alive request timeout of 500ms. This timeout is especially important when taken into consideration with Spring’s default keep-alive timeout of 5 seconds. After the first request, the HAProxy will close the connection after 500ms by sending a [FIN, ACK] packet (31). 

*The big surprise: the Spring HTTP client (i.e. the application layer) does not check for this packet (by reading from the socket), and believes the connection is still open. The kernel on the TCP layer can acknowledge the [FIN, ACK] packet independent of the application layer, and our Spring HTTP client is none the wiser.*

Then, the Spring HTTP client will try to re-use the connection on the second request despite the connection having been closed by the HAProxy, causing the 500 error.


## Takeaways

### Establishing Best Practices for Network Component Setup

Keep-alive timeouts at various stages of the deployment topology were a key factor in this investigation. We noticed a pattern we thought we should bring to the attention of the community. 

Let’s look from the “outside” (the client) to the “inside” (the server in the deployment). As you travel further in, the keep-alive timeouts should be configured to be longer. That is, the outermost layer (in this case, the client) should have the shortest backend keep-alive timeout, and as you go in, the keep-alive timeouts should get progressively longer in relation to the corresponding backend or frontend idle timeout, as we’ve illustrated below:

{{< responsive-figure src="/images/understanding_keep_alive_timeouts/establishing_best_practices.jpg" class="center" >}}

This kind of relative networking configuration policy is not strictly necessary. However, you can think of it as defensive configuration for cases like the one we have described (e.g. when connections are closed due to keep-alive timeouts and the app is not configured to open new connections for subsequent requests). As a further mitigation, we’ve also [updated the HAProxy BOSH release default frontend keep-alive timeout](https://github.com/cloudfoundry-incubator/haproxy-boshrelease/commit/583d2b0bc350edca6c07ed33197e56b607d91498) to be more tolerant to a wider variety of HTTP clients.

### Future Spring Framework Enhancements?

The Spring HTTP client’s default behavior also caught our attention and we would like to encourage discussion on the topic. Ideally, application developers should use a HTTP client that will check for closed connections from the server. It appears the Spring HTTP client does not implement this functionality.

Consider Golang’s HTTP client, which we believe to be somewhat robust to this type of client-side problem. The low level `http` transport package used by the default client implements a [background loop](https://github.com/golang/go/blob/54f5a6674a9463fecb8656c9ffc6d80374c5868d/src/net/http/transport.go#L1675-L1681) that checks if a connection in its idle pool has been closed by the server before reusing it to make a request. This leaves a small window for a race condition where the server could close the connection between the check and the new request; in the event that the client loses this race, it [retries this request on a new connection](https://github.com/golang/go/blob/54f5a6674a9463fecb8656c9ffc6d80374c5868d/src/net/http/transport.go#L550-L555).

Should we enhance the Spring HTTP client to do this as well?
