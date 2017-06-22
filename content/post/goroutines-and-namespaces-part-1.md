---
authors:
- grosenhouse
categories:
- containers
- linux
date: 2016-12-06T18:01:29-08:00
draft: false
short: |
  Hands on with Linux namespaces and threads
title: "Don't mix goroutines and namespaces: Part 1"
---

Here's an obscure fact!

```text
A concurrent Go program cannot safely switch namespaces.
```

What does that even mean???

Have you heard of these fancy "container" things, but are curious how they actually work?  Perhaps you're a Go programmer who wants to better understand the concurrency features in your language runtime?

Or maybe you just want to hear a story about a [super gnarly bug](https://github.com/containernetworking/cni/issues/262) that keeps popping up in the open source container ecosystem — most recently on the [CNI project](https://github.com/containernetworking/cni) — where a server spontaneously loses network connectivity, for no apparent reason?

In this 3-part series, we'll cover it all:

- Part 1 (that's today!): learn about **namespaces** and how they interact with *threads*
- Part 2: learn about **goroutines**
- Part 3: we **mix them together** and observe the result (spoiler alert: bad things happen)

---

The rough outline for Part 1 is:

- [Background: What's a namespace?]({{< relref "#background-what-s-a-namespace" >}})
- [Working with namespaces]({{< relref "#working-with-namespaces" >}})
- [Running a server in a namespace]({{< relref "#running-a-server-in-a-namespace" >}})
- [Switching namespaces in code]({{< relref "#switching-namespaces-in-code" >}})
- [One process in many namespaces!]({{< relref "#one-process-in-many-namespaces" >}})
- [Inheritance]({{< relref "#inheritance" >}})

Sound good?  OK.  Here we go.

---

## Background: What's a namespace?
Modern cloud application platforms like Cloud Foundry are built on a technology called *containers*.  Although containers have been recently popularized by products like Docker, most of the underlying technology has [been around for years](https://en.wikipedia.org/wiki/Operating-system-level_virtualization) and incorporated into many systems.  The basic concept is simple: an operating system [*process*](<https://en.wikipedia.org/wiki/Process_(computing)>) that is "inside" the container is isolated from everything else outside.  It can't see any other processes on the host computer, it gets its own filesystem, and has its own address on the network.

On Linux, each of these forms of isolation (process table, filesystem mounts, network and others) is provided by a different kind of [*namespace*](http://man7.org/linux/man-pages/man7/namespaces.7.html).  If a process is in a [*PID namespace*](http://man7.org/linux/man-pages/man7/pid_namespaces.7.html), it can only see other processes inside that namespace.  Likewise, a filesystem mounted on the host won't be visible to processes inside of a [*mount namespace*](http://man7.org/linux/man-pages/man7/mount_namespaces.7.html).  And if I simultaneously launch 100 different web server processes, each inside a different *network namespace*, every one could bind to the same port number at the same time, because each has its own network stack.

In short, a container is just a bundle of namespaces of different kinds (pid, mount, network and others), along with a few extra kernel features to enforce quotas and lock down security.  Every container runner, including Docker, rkt, and Garden (part of Cloud Foundry) does this similarly.  In fact, you can build your own container in [less than 100 lines of Go](https://www.infoq.com/articles/build-a-container-golang).

But this is a post about namespaces.  So let's dive into namespaces.  Specifically *network namespaces*...

---

We'll work through several examples that will require `root` access on a Linux environment.  If you're on Mac or Windows, or are a Linux user that would rather keep your network tinkering inside a sandbox, then you can set up a Linux virtual machine:

0. Install [Vagrant](https://www.vagrantup.com/)
0. Install [VirtualBox](https://www.virtualbox.org/)
0. In an empty directory, open a terminal and run

   ```bash
   vagrant init ubuntu/xenial64
   vagrant up
   vagrant ssh
   ```

---

## Working with namespaces

Here's a quick demo.  We'll manipulate some [`iptables` firewall](https://en.wikipedia.org/wiki/Iptables) rules inside a network namespace without it affecting the firewall rules on the host.

```bash
# become root
sudo su

# show the iptables rules on the host computer
iptables -S
## -P INPUT ACCEPT
## -P FORWARD ACCEPT
## -P OUTPUT ACCEPT

# make three new network namespaces
ip netns add apricot
ip netns add banana
ip netns add cherry

# list the network namespaces
ip netns list
## apricot
## banana
## cherry

# within the namespace "cherry", execute "iptables -S"
ip netns exec cherry iptables -S
## -P INPUT ACCEPT
## -P FORWARD ACCEPT
## -P OUTPUT ACCEPT

# within the namespace "cherry", add an iptables rule
ip netns exec cherry iptables -A FORWARD -j ACCEPT -d 1.2.3.4

# within the namespace "cherry", list the rules again
ip netns exec cherry iptables -S
## -P INPUT ACCEPT
## -P FORWARD ACCEPT
## -P OUTPUT ACCEPT
## -A FORWARD -d 1.2.3.4/32 -j ACCEPT

# see that the new rule is not visible on the host
iptables -S
## -P INPUT ACCEPT
## -P FORWARD ACCEPT
## -P OUTPUT ACCEPT
```

The [`ip netns` utility](http://man7.org/linux/man-pages/man8/ip-netns.8.html) maintains network namespaces as files in the `/var/run/netns` directory:
```bash
ls -1 /var/run/netns
## apricot
## banana
## cherry
```

The names are helpful, but the [inode](https://en.wikipedia.org/wiki/Inode) number of the file uniquely identifies the namespace:
```bash
ls -i -1 /var/run/netns
## 4026532297 apricot
## 4026532181 banana
## 4026532233 cherry
```

For example, when we launch a new process in a namespace, the namespace file's inode and the process's netns inode match:
```bash
ls -i /var/run/netns/apricot
## 4026532297 /var/run/netns/apricot

ip netns exec apricot sleep 1000 &
## [1] 7464

SLEEP_PID=$!

readlink /proc/$SLEEP_PID/ns/net
## net:[4026532297]
```

---

## Running a server in a namespace
Namespaces are used to build containers, and containers often run servers.  One of the advantages of namespaces is that the process inside can bind to whatever port it likes, without interference from other processes.

Let's try that out.  First, we'll launch a simple [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol) server from the host:
```bash
while (sleep 1); do
  echo "hello from host";
done | nc -lk 5000 &
```
We can see the server is listening on port 5000:
```bash
lsof -i
## COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
## nc      10468 root    3u  IPv4  34530      0t0  TCP *:5000 (LISTEN)
```
And when we connect to it with a client, we see a hello message sent every second:
```bash
nc localhost 5000
## hello from host
## hello from host
## hello from host
```


Next, we'll launch another server, listening on the same port, but from inside the `cherry` namespace:
```bash
ip netns exec cherry /bin/bash -c 'while (sleep 1); do echo "hello from cherry"; done | nc -lk 5000' &
```

We can now see this server is *also* listening on port 5000, but inside the namespace:
```bash
ip netns exec cherry lsof -i
## COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
## nc      11255 root    3u  IPv4  39853      0t0  TCP *:5000 (LISTEN)
```

But, we can't actually connect to the server yet.  This command just hangs!
```bash
ip netns exec cherry nc -v localhost 5000
```

That's because the loopback network device, the one named `lo`, is `DOWN`.
```bash
ip netns exec cherry ip link list
## 1: lo: <LOOPBACK> mtu 65536 qdisc noqueue state DOWN mode DEFAULT group default qlen 1
##     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
```

Let's bring it up:
```bash
ip netns exec cherry ip link set lo up
ip netns exec cherry ip link list
## 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1
##     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
```

Now, from inside the `cherry` namespace, we can connect to the server:
```bash
ip netns exec cherry nc localhost 5000
## hello from cherry
## hello from cherry
## hello from cherry
## hello from cherry
## ...
```

What have we learned?  Every new network namespace comes with a built-in `lo` virtual network device.  But that device needs to be brought `up` before the network namespace is usable.

Let's clean up a bit before moving on
```bash
kill $(jobs -p)
```

While we're at it, let's bring up the loopback device in all 3 namespaces:
```bash
for ns in $(ip netns list); do
  ip netns exec $ns ip link set lo up
done
```

---

## Switching namespaces in code
A process does not need to stay in the same namespace it started in.  To illustrate this, we'll implement the `ip netns exec` utility ourselves!

> Although the later posts in this series will focus on the Go programming language, today we'll only code in C.  That's because its easier to use Linux kernel primitives, like namespaces and threads, in C than in Go.


Here's the complete source code for (a somewhat simplified version of) `ip netns exec`:
```c
// netns-exec.c

#define _GNU_SOURCE
#include <fcntl.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv)
{
  if (argc < 2) {
    fprintf(stderr, "usage: %s namespace program args...\n", argv[0]);
    exit(1);
  }

  // acquire a handle to the namespace
  int namespaceFd = open(argv[1], O_RDONLY);
  if (namespaceFd == -1) {
    fprintf(stderr, "error: open %s\n", argv[1]);
    exit(1);
  }

  // switch this thread to the namespace
  if (setns(namespaceFd, 0) == -1) {
    fprintf(stderr, "error: setns\n");
    exit(1);
  }

  // execute the program
  if (execvp(argv[2], &argv[2]) < 0) {
    fprintf(stderr, "error: execvp\n");
    exit(1);
  }
}
```

> To see complete source code and build scripts for this and all other code samples in this post, [click here](https://github.com/rosenhouse/ns-mess/tree/master/c-demos).

---

If you're working in the Vagrant environment, run these commands to get a C compiler:

```bash
apt-get -y update
apt-get -y install gcc
```

---

Build it:
```bash
mkdir -p bin
gcc netns-exec.c -o bin/netns-exec
```

and try it out, passing in the full path to a namespace and a command to run:
```bash
bin/netns-exec /var/run/netns/banana ip addr
## 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
##     link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
##     inet 127.0.0.1/8 scope host lo
##        valid_lft forever preferred_lft forever
##     inet6 ::1/128 scope host
##        valid_lft forever preferred_lft forever
```

---

## Sidebar: a namespace is not a file

We can refer to the namespace by a path other than the one at `/var/run/netns`.  Recall that the network namespace for any process is available at `/proc/$PID/ns/net`.  In fact, we can launch a process in a namespace, knowing only the PID of some process that is already inside:

```bash
ip netns add dragonfruit
ip netns exec dragonfruit ip link set lo up

ip netns exec dragonfruit /bin/bash -c 'while (sleep 2); do echo "hi from dragonfruit"; done | nc -lk 5000' &

SERVER_PID=$!

bin/netns-exec /proc/$SERVER_PID/ns/net nc localhost 5000
## hi from dragonfruit
## hi from dragonfruit
## hi from dragonfruit
## hi from dragonfruit
## ...
```

In fact, we can delete the namespace reference on disk:
```bash
ip netns delete dragonfruit
```

But because there is still a process inside, the namespace remains alive and well.  We can re-connect to it, again by its PID:
```bash
bin/netns-exec /proc/$SERVER_PID/ns/net nc localhost 5000
## hi from dragonfruit
## hi from dragonfruit
## hi from dragonfruit
## hi from dragonfruit
```

It's only when we finally stop all the processes inside that the kernel deletes the namespace:
```bash
kill $(jobs -p)
```

---



## One process in many namespaces!
Perhaps the most surprising fact about namespaces is that a single process can reside in multiple namespaces simultaneously.  This is possible because, in Linux, namespace association is *per-thread*, not per-process.

In a single-threaded program, like `netns-exec` above, this distinction doesn't matter.  But if we write a multi-threaded program, each thread could reside in a different namespace.

To show this, we'll write a simple TCP echo server which listens simultaneously in multiple network namespaces, and customizes its echo reply based on the namespace.  This is easier than it sounds.

We'll start with a basic single-threaded TCP server, `listenAndServe()`:
```c
void listenAndServe(char* message) { ... }
```
It loops forever, waiting for connections.  When a client connects, the server sends the `message` to the client and then disconnects.
([full source here](https://github.com/rosenhouse/ns-mess/blob/master/c-demos/tcp-hello.c))


Next, we'll define the `threadWorker()` function that will be the entry point for each new thread.  It has two responsibilities: change the thread's network namespace, then launch the TCP server:
```c
#define BUFFER_SIZE 1024

void* threadWorker(char* namespacePath) {
  // acquire a handle to the namespace
  int namespaceFd = open(namespacePath, O_RDONLY);
  if (namespaceFd == -1) {
    perror("error: open namespace");
    exit(1);
  }

  // switch this thread to the namespace
  if (setns(namespaceFd, 0) == -1) {
    perror("error: setns");
    exit(1);
  }

  fprintf(stderr, "\nstarting a server in namespace %s\n", namespacePath);

  char message[BUFFER_SIZE];
  snprintf(message, BUFFER_SIZE, "hello from namespace %s\n", namespacePath);

  listenAndServe(message);

  return NULL;
}
```

Finally, we'll write our program's `main()`.  It expects as command line arguments one or more namespace file paths.  It starts a [pthread](http://man7.org/linux/man-pages/man7/pthreads.7.html) for each namespace and then pauses, waiting for a signal to halt:

```c
int main(int argc, char **argv) {
  if (argc <= 1) {
    fprintf(stderr, "usage: %s nspath1 nspath2 ...\n", argv[0]);
    exit(1);
  }

  int numNamespaces = argc - 1;
  char** namespacePaths = &argv[1];

  for (int i = 0; i < numNamespaces; i++) {
    pthread_t thread;
    pthread_create(&thread, NULL,
        (void *(*) (void *)) threadWorker,
        (void *) namespacePaths[i]
    );
  }

  pause();
}
```

Make sure you build with pthreads support:
```bash
gcc tcp-hello.c -pthread -o bin/tcp-hello
```

Let's boot this thing:

```bash
find /var/run/netns/*
## /var/run/netns/apricot
## /var/run/netns/banana
## /var/run/netns/cherry

bin/tcp-hello $(find /var/run/netns/*) &
## starting a server in namespace /var/run/netns/banana
##
## starting a server in namespace /var/run/netns/apricot
##
## starting a server in namespace /var/run/netns/cherry
```

Does it blend?
```bash
ip netns exec apricot nc localhost 5000
## hello from namespace /var/run/netns/apricot

ip netns exec banana nc localhost 5000
## hello from namespace /var/run/netns/banana
```
That's it!  A single process `tcp-hello` is servicing requests in multiple namespaces.

Remember how we accessed the namespace via the PID of the process inside?  We can do the same trick using thread IDs (TID) within a process.  These appear in the `/proc` tree under `/proc/PID/task/TID/ns/net`:

```bash
SERVER_PID=$(pgrep tcp-hello)

ls /proc/$SERVER_PID/task/
## 11031  11033  11034  11035

readlink /proc/$SERVER_PID/task/11033/ns/net
## net:[4026532297]

ls -i1 /var/run/netns
## 4026532297 apricot
## 4026532181 banana
## 4026532233 cherry
```

On my system, it appears that thread `11033` has inode `4026532297` , which is the same inode as for namespace `apricot`.  Let's check:
```bash
bin/netns-exec /proc/$SERVER_PID/task/11033/ns/net nc localhost 5000
## hello from namespace /var/run/netns/apricot
```
We can enter the namespace of each thread individually, and reach the TCP server inside.  Nifty.

---

## Inheritance
To introduce our final topic for today, we'll start with this question:

> Suppose a program is launched in the host namespace.  The main thread switches
> to the `banana` namespace and then calls `pthread_create` to start a second thread.
> In what namespace does the second thread begin its life?

To answer this, we're going to write our final C program for today.

We'll skip the boilerplate ([full source here](https://github.com/rosenhouse/ns-mess/blob/master/c-demos/inherit.c)) and jump into the `report` function to print the current thread ID and network namespace inode number:
```c
int getThreadID() {
  return syscall(SYS_gettid);
}

long int getInodeOfCurrentNetNS() {
  char myNSPath[100];
  sprintf(myNSPath, "/proc/self/task/%d/ns/net", getThreadID());

  int currentNS = open(myNSPath, O_RDONLY);
  if (currentNS < 0) {
      perror("error: open namespace");
      exit(1);
  }

  struct stat nsStat;
  if (fstat (currentNS, &nsStat) < 0) {
      perror("error: stat namespace");
      exit(1);
  }
  close(currentNS);

  return nsStat.st_ino;
}

void report(char* msg) {
  fprintf(stdout, "%20s: on thread %d in netns %lx\n", msg, getThreadID(), getInodeOfCurrentNetNS());
}
```

Next, we'll define a thread worker which calls `report` to print its current namespace and then quits.
For clarity, we'll make a helper function that both spins up the new thread *and* waits for it to complete.
```c
void* threadWorker(void* _) {
  report("in new thread");
  return NULL;
}

void launchThreadAndWait() {
  pthread_t thread;
  pthread_create(&thread, NULL,
        (void *(*) (void *)) threadWorker,
        (void *) NULL
    );

  void* res;
  // wait for the thread to complete
  if (pthread_join(thread, &res) != 0) {
    perror("error: join");
    exit(1);
  }
}
```

Finally, we write our `main`:
```c
int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "usage: %s nspath1\n", argv[0]);
    exit(1);
  }

  report("main started");

  switchToNamespace(argv[1]);
  printf("switched to %s\n", argv[1]);
  report("main, after switch");

  printf("creating new thread...\n");
  launchThreadAndWait();
}
```

As before, we need to compile with pthreads support:
```bash
gcc inherit.c -pthread -o bin/inherit
```

Now we can answer our question:
```bash
bin/inherit /var/run/netns/banana
##         main started: on thread 25196 in netns 4026531957
## switched to /var/run/netns/banana
##   main, after switch: on thread 25196 in netns 4026532181
## creating new thread...
##        in new thread: on thread 25197 in netns 4026532181
```

We see the main thread switches to namespace `banana` (a.k.a. inode number `4026532181`) and starts a new thread, which starts life in the same network namespace.

More generally:

>A child thread inherits the namespaces of its parent.

This may seem obvious and [the only way things could possibly work](https://en.wikipedia.org/wiki/Canonical_map).  But it is worth stating explicitly.  When we dig into the root cause of our bug in Part 3, this fact will be very important.  Stay tuned!

---

Before we finish, let's do some housekeeping:
```bash
kill $(jobs -p)
ip -all netns delete
```

---


## Wrapping up, for now

Part 1 complete!  You've:

- learned what a namespace is and how it relates to containers
- created network namespaces
- launched programs inside of those namespaces
- observed parts of the network stack, and how it is isolated inside a network namespace
- written a program that changes what namespace it is in
- written a multi-threaded, multi-namespace TCP server!
- proven that child threads are born into the same namespace as their parent

If you want to explore more, check out the [manual pages for `namespaces`](http://man7.org/linux/man-pages/man7/namespaces.7.html) and the [documentation for the `ip` utility](http://man7.org/linux/man-pages/man8/ip-netns.8.html) (and [here](http://baturin.org/docs/iproute2/)).  A couple things to try with the latter:

- Kick the tires on `ip netns pids` and `ip netns identify`.  Do they work when the threads are in different namespaces?
- Create a "virtual ethernet" pair using `ip link add`, then try to "connect one namespace to another" using `ip link set dev`.  Can you make a network connection (via `nc`) from one namespace to another?

Next time, we'll dive into Go language *goroutines*, what problems they solve and how they are different from threads.

## UPDATE
I got busy and never wrote parts 2 and 3, BUT the excellent folks at Weave Works have a
[great blog post](https://www.weave.works/blog/linux-namespaces-and-go-don-t-mix) covering most of what I was aiming for.
You may also be interested in [this GitHub issue](https://github.com/golang/go/issues/20676) which may provide a real fix
in Go 1.10.
