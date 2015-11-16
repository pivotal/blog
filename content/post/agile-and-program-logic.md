---
authors: 
- gareth
categories:
- Agile
date: 2015-10-17T14:48:36+01:00
short: |
  On some of the differences and similarities in perspective between Agile/TDD
  programmers and developers of program-logic tools. 
title: Agile and Program Logic
---

I just started at Pivotal a couple of months ago. Before that, I worked on
formal methods, program logic, and semantics. My [old
colleagues](http://www.resourcereasoning.com/people.html) in academia and my
new colleagues in industry are all aiming at the same thing -- we want to build
awesome software. In this post I want to talk about some of our differences in
perspective; and how that affects the sorts of tools that my old colleagues
produce, and the sorts of tools my new colleagues are likely to want to use.

Here's the most important bit of this blog post. I think that if you want to
make awesome software (which is reliable, and which does something that's
useful to someone), you need to do three things:

Discovery
: Figure out what you want

Implementation
: Write code that does what you said you wanted

Cost
: Manage _Discovery_ and _Implementation_ within the constraints of your local
  economics[^1].

Academic computer scientists - quite rightly - tend to focus on
_Implementation_. There are good reasons for this - success in _Implementation_
is relatively easy to measure, even if you're developing a small prototype in
isolation from the market it's ultimately aimed at. On the other hand, I think
Agile/TDD (Test Driven Development) is really good at _Discovery_. When I
was living in academia I often found myself arguing that formal methods and
proof-based techniques were better at _Implementation_ than TDD can ever
be[^2].  This might be true[^3], but it misses the point. The
point is that it doesn't matter how good an engineer is at _Implementation_ if
they have no plan for _Discovery_. For the rest of this post, I'm going to
explore the strategy we use at Pivotal for _Discovery_ and what that might
mean for academic toolsmiths who want us to use their methods and tools when we
come to do _Implementation_.  Many of the things I mention here will also turn
out to be quite handy for managing _Cost_ as well, but to do that justice will
require another post.

## Agile/TDD at Pivotal

{{< figure src="/images/pairing.jpg" class="left small" >}}

There are [lot](https://en.wikipedia.org/wiki/Extreme_programming)
[of](https://en.wikipedia.org/wiki/Test-driven_development)
[places](https://www.destroyallsoftware.com/screencasts) to read about
Agile/TDD online, and you've almost certainly read this sort of thing before.
I'm repeating it here for easy context, and because I don't want to describe
and evangelise some TDD theory that no-one practices -- I want to describe what
I actually do every day. If you don't currently do these things and you want to
give them a try, that's awesome. But in the context of this post it's more
important to describe to my old colleagues what sort of process their tools are
going to need to slot in to if they want me to use them.

So here we go:

Every new feature, every bugfix, every change to our codebase is a story in our
tracker. These stories are prioritized by the Product Manager (PM). Our
engineers work in pairs. Each pair uses a single machine at a given time with
two monitors, keyboards and mice. Each pair picks the highest priority task
from the tracker, and makes it happen. To make a story happen, you write a
test, make it pass, push to master, repeat. The master branch of our git repo
contains all the things all of us are currently working on, and all the tests
always pass.

Let's look in to some of that in more detail.

### Imaginary Case Study: The Machine That Goes Ping

{{< figure src="/images/ping-machine.jpg" class="right small" >}}

Suppose we're building a client-server application for some customer. The
customer has asked for a whole bunch of things, and (with more or less help
from our PM, depending on various factors) has written up a bunch of stories in
our tracker. There might be a story called "introduce ping button". This story
will have some "acceptance criteria" attached. The idea is that once the
engineers think they've finished the story the PM should be able to read the
acceptance criteria; try out the new functionality; and decide whether the
engineers did their job right, or whether they need another go. For this story,
our acceptance criteria might look something like this:

1. start the server in one terminal with `servergui`
1. start client in another terminal with `appclient --connect localhost`
1. press ping button on server
1. I expect to see "Ping!" on the client term.


This is an informal description of what the customer thought they wanted. There
are various problems with it as a specification. For example, do we expect the
ping message to propagate to all clients currently connected, or only to some
of them? Which ones? If a client isn't connected during the broadcast, do we
expect the message to be stored, and delivered when the client eventually
connects? The Agile/TDD process will help us clear all this up.

The first thing the pair of engineers working on this story will do is write an
integration test. This test should be as simple as possible a formalization of
the loose informal specification in the story. For example:

```
Describe("Pinger", func() {
  var server Server
  var client Client
  var testLogger Logger

  BeforeEach(func() {
    server = NewServer(....)
    testLogger = TestLogger{}
    client = NewClient(.... testLogger ... )
    client.Connect(server.Address())
  })

  It("Can ping the client", func() {
    server.Ping()
    Eventually(testLogger).Should(Say("Ping!"))
  })
})
```

I've written this example test in [go](https://golang.org/) (missing a few
details about how we actually start our imaginary server and so on), following
the patterns encouraged by the testing library
[ginkgo](https://github.com/onsi/ginkgo). We will see as tests get more
complicated that the strings in the blocks labelled `Describe`, `It`, and
similar encourage us to write our tests in a specification-like way. We
describe things, and properties of things. Later we will see how to describe
context-specific properties of things, and organize our properties into
hierarchies of contexts. For now, notice that this test describes exactly what
the customer asked for -- what they thought they wanted -- and makes no attempt
to guess what extra things they might want. This test deliberately says nothing
about multiple clients, or offline clients.

The pair of engineers working on this story are now free to make this test pass
any way they like -- so long as the code they write is test-driven with
unittests.

### Clarifying the Spec

{{< figure src="/images/magnifying-code.jpg" class="left small" >}}

For our narrative, let us assume that while the engineers were writing the test
above, they realised that it would pass even if the server never attempts to
send messages to more than one client. On this occasion, the engineers decide
to ask the PM for clarification. The PM replies "Oh yes -- I think we want a
proper broadcast message there, not just a message to a single random client".
In the ensuing conversation, the PM and the engineers could choose to finish
this story quickly with just the one integration test, and to open a new story
for making our ping into a broadcast message... Or they could choose to update
the existing story (which is still "in-flight") to reflect their new shared
understanding of the problem. In our example, they choose the second option:
the PM updates the acceptance criteria to mention multiple clients, and the
engineers make a note to write a second integration test once they have the
first one passing.

With the new test added, the tests for this story now look like this:


```
Describe("Pinger", func() {
  var server Server
  var client Client
  var testLogger Logger

  BeforeEach(func() {
    server = NewServer(....)
    testLogger = TestLogger{}
    client = NewClient(.... testLogger ... )
    client.Connect(server.Address())
  })

  It("can ping the client", func() {
    server.Ping()
    Eventually(testLogger).Should(Say("Ping!"))
  })

  Context("when there are multiple clients", func() {
    var secondClient Client
    var secondLogger Logger

    BeforeEach(func() {
      secondLogger = Logger{}
      secondClient = NewClient( ... secondLogger ... )
      secondClient.Connect(server.Address())
    })

    It("pings all of them", func() {
      server.Ping()
      Eventually(testLogger).Should(Say("Ping!"))
      Eventually(secondLogger).Should(Say("Ping!"))
    })
  })
})
```

The engineers make this test pass (with unittests for every change they make on
the way), mark the story as finished, and move on to something else. Job done.

### Changing Your Mind
{{< figure src="/images/change-mind.jpg" class="right small" >}}

The PM is now free to bring the current version of the software to the client,
to see what they think. The client might be entirely happy with what the team
gives them, or they might realise they actually wanted something a little
different, or a little more tightly specified than what they first asked for.
This is totally fine. In our story, let us imagine that the client realised
they wanted the ping message to eventually reach even offline clients -- the
next time they connect. The client can request a new story: "enable offline
pinging"

1. start the server in one terminal with `servergui`
1. press the ping button on the server gui
1. start client in another terminal with `appclient --connect localhost`
1. I expect to see "Ping!" on the client term.

The PM will prioritise this story, and it will eventually be picked up by a
pair of engineers who might update the tests in the following way:

```
Describe("Pinger", func() {
  var server Server
  var client Client
  var testLogger Logger

  BeforeEach(func() {
    server = NewServer(....)
    testLogger = TestLogger{}
    client = NewClient(.... testLogger ... )
    client.Connect(server.Address())
  })

  It("can ping the client", func() {
    server.Ping()
    Eventually(testLogger).Should(Say("Ping!"))
  })

  Context("when there are multiple clients", func() {
    var secondClient Client
    var secondLogger Logger

    BeforeEach(func() {
      secondLogger = Logger{}
      secondClient = NewClient( ... secondLogger ... )
    })

    It("pings both of them", func() {
      secondClient.Connect(server.Address())
      server.Ping()
      Eventually(testLogger).Should(Say("Ping!"))
      Eventually(secondLogger).Should(Say("Ping!"))
    })

    Context("when the second client connects after the ping has been sent", func() {
      It("pings the second client when it does connect", func() {
        server.Ping()
        Eventually(testLogger).Should(Say("Ping!"))
        secondClient.Connect(server.Address())
        Eventually(secondLogger).Should(Say("Ping!"))
      })
    })
  })
})
```

Notice that the new test (which we may view as a partial specification)
composes perfectly with the existing tests. We didn't waste any effort when we
were working on the first thing the client thought they wanted. When the client
changed/clarified their mind, we were able to evolve the code we'd already
written into what they now realised they wanted. For this to work we absolutely
need a very local kind of expressivity in our specification language. We want
to be able to write large numbers of tiny partial-specifications, and we want
them to trivially compose.

## Formal Methods

So what can formal methods research do for us?

I'm going to guess some answers to this question biased heavily by my
experience with [separation
logic](http://www0.cs.ucl.ac.uk/staff/p.ohearn/papers/Marktoberdorf11LectureNotes.pdf),
but I hope some ideas may be more generally applicable.

### Tools
{{< figure src="/images/infer.png" class="left small" >}}

Recently, Facebook open-sourced the [Infer](http://fbinfer.com/) tool. This is
a separation-logic based shape-analysis tool, which can detect things like
memory leaks, buffer overruns, null pointer accesses and so on. My imperfect
understanding of their use of that tool is that it runs in their CI after code
has been pushed to their version-control system, and often provides useful
input to the code-review process which (at Facebook) happens after the code has
been written, but before it gets into production. This seems to be (*very*)
loosely analogous to the time when the PM checks the acceptance criteria in the
Pivotal process. FB-Pivotal process differences aside, having a broad-sweep
static analysis as powerful as Infer in the CI is an awesome and beautiful
thing. But I think we can do better.

### Locality 
{{< figure src="/images/east-london-massive.png" class="right small" >}}

Separation logic people like to talk about "local specifications". They write
specifications that talk about the state of the program-memory before and after
running whatever piece of code they're talking about. By "local" they mean that
they only talk about the bits of memory that the program cares about (needs to
read from or write to). Advantages of local separation logic specifications are
that they compose neatly, and they reduce the amount of effort (mental for a
human, computational for a tool) needed to prove that a given program does as
it claims to.

I've just claimed that Pivotal people care about "local partial
specifications". By this, I mean specifications that trivially compose, and
which say the absolute minimum needed to describe a single feature.

Tools like Infer do a great job of allowing engineers to reap some of the
benefits of separation-logic reasoning without needing to learn separation
logic themselves. I'd like to explore if we can do even better by exploiting
the similarities in our ideas of what "local" means. To start the ball rolling,
here are some tests it might be fun to be able to write:

```
Expect(foo()).DoesNotLeakMemory()

Expect(foo()).CannotCrash()

Expect(foo()).CannotCrash(SoLongAs(bar)) // Where `bar` is a boolean expression
```

The first two aren't necessarily very interesting (Infer will already do this
for your whole codebase, so why bother for just one function?) except that they
naturally lead to the third. An Infer-like tool could use the boolean
expression `bar` to infer the footprint of the function `foo`, and then attempt
to prove memory-safety given that footprint as a precondition. I think this
barely scratches the surface of what might be possible.

Recall the list of three things I claimed you need to build awesome software
(right at the top of this page). Wouldn't it be great if engineers working on
_Discovery_ and academics working on _Implementation_ had independently
stumbled on the same idea of "locality"? If so, then that commonality might be
interesting in its own right; but perhaps it could also be exploited by
academic toolsmiths to produce some awesome new tools that fit well into our
processes here in industry.

## Coming Soon

In this post I was aiming to make the connection between the TDD virtue of
small tests, and the separation logic concept of locality. If this sort of
cross-over between formal methods and Agile interests you, then drop me a line,
or keep an eye on this blog. Next up, I'd like to write about [property-based
testing](http://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html) (which is
also available [to Go programmers](https://golang.org/pkg/testing/quick/) out
of the box) and how that may or may not fit into my day to day workflow.

[^1]:   Of course your local economic constraints could be very
        different to someone else's. You might be working in Silicon Valley on
        a VC funded project, looking to demonstrate market value by selling app
        subscriptions; or you might be working for a European government on a
        publicly funded project, looking to demonstrate public value by
        improving the quality of life of your citizens without making any
        money; or you might be working on an open source project fueled by
        volunteer time, looking to improve your reputational value by doing
        something people think is cool.

[^2]:   Or at least at verifying that you did your _Implementation_ work right 
        when you wrote the code. [Some formal
        methods](https://en.wikipedia.org/wiki/Refinement_\(computing\)#Program_refinement)
        will tell you how to write the code such that it does the right thing,
        while others will only reassure you that the code you were writing
        anyway was good code.

[^3]:   Or it might not. It's beyond the scope of this little blog post.

