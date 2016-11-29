---
authors:
- grosenhouse
categories:
- containers
- linux
date: 2016-11-23T23:01:29-08:00
draft: true
short: |
  Hands on with Linux network namespaces
title: "Don't mix goroutines and namespaces: Part 1"
---

Here's an obscure fact!

>```text
A concurrent Go program cannot safely switch namespaces.
```

What does that even mean???

Have you heard of these fancy "container" things, but are curious how they actually work?  Perhaps you're a Go programmer who wants to better understand the concurrency features in your language runtime?  Or maybe you just want to hear a story about a super gnarly bug, one where your server randomly decides it can't reach the network, for no apparent reason?

In this 3-part series, we'll cover it all:

- Part 1 (that's today!): learn about **namespaces**
- Part 2: learn about **goroutines**
- Part 3: we **mix them together** and observe the result (spoiler alert: bad things happen)

Sound good?  OK.  Here we go.

## What's a namespace?
Modern cloud application platforms like Cloud Foundry are built on a technology called *containers*.  Although containers have been recently popularized by products like Docker, most of the underlying technology has been around for years and incorporated into many systems.  The basic concept is simple: an operating system *process* that is "inside" the container is isolated from everything else outside.  It can't see any other processes on the host computer, it gets its own filesystem, and has its own address on the network.

On Linux, each of these forms of isolation (process table, filesystem mounts, network and others) is provided by a different kind of *namespace*.  If a process is in a *PID namespace*, it can only see other processes inside that namespace.  Likewise, a filesystem mounted on the host won't be visible to processes inside of a *mount namespace*.  And if I simultaneously launch 100 different web server processes, each inside a different *network namespace*, every one could bind to the same port number at the same time, because each has its own network stack.

In short, a container is just a bundle of namespaces of different kinds (pid, mount, network and others), along with a few extra kernel features to enforce quotas and lock down security.  Every container runner, including Docker, rkt, and Garden (part of Cloud Foundry) does this similarly.  In fact, you can build your own container in [less than 100 lines of Go](https://www.infoq.com/articles/build-a-container-golang).

But this is a post about namespaces.  So let's dive into namespaces.  Specifically *network namespaces*...


## Working with namespaces
Here's a quick demo.  We'll manipulate the some `iptables` firewall rules inside a network namespace without it affecting the firewall rules on the host.

```bash
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

The `ip netns` utility maintains network namespaces as files in the `/var/run/netns` directory:
```bash
ls -1 /var/run/netns
## apricot
## banana
## cherry
```

The names are helpful, but the [inode](https://en.wikipedia.org/wiki/Inode) number of the file uniquely identifies the namespace:
```bash
ls -i -1 /var/run/netns
## 4026532129 apricot
## 4026532181 banana
## 4026532233 cherry
```

For example, when we launch a new process in a namespace, the namespace file's inode and the process's netns inode match:
```bash
ls -i /var/run/netns/apricot
## 4026532129 /var/run/netns/apricot

ip netns exec apricot sleep 1000 &
## [1] 7464

SLEEP_PID=$!

readlink /proc/$SLEEP_PID/ns/net
## net:[4026532129]
```

---

## Running a server in a namespace
Namespaces are used to build containers, and containers often run servers.  One of the advantages of namespaces is that the process inside can bind to whatever port it likes, without interference from other processes.

Let's try that out.  First, we'll launch a simple TCP server from the host:
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

While we're at it, lets bring up the loopback device in all 3 namespaces:
```bash
for ns in $(ip netns list); do
  ip netns exec $ns ip link set lo up
done
```


## Switching namespaces in code
A process does not need to stay in the same namespace it started in.  To illustrate this, we'll implement the `ip netns exec` utility ourselves!  It's only a few lines of C:

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
(full [source here](https://github.com/rosenhouse/ns-mess/blob/master/c-demos/netns-exec.c))

Build it:
```bash
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

ip netns exec dragonfruit /bin/bash -c 'while (sleep 1); do echo "hi from dragonfruit"; done | nc -lk 5000' &

SERVER_PID=$!

bin/netns-exec /proc/$SERVER_PID/ns/net nc localhost 5000
```

In fact, we can delete the namespace reference on disk:
```bash
ip netns delete dragonfruit
```

But because there is still a process inside, the namespace remains alive and well.  We can re-connect to it, again by its PID:
```bash
bin/netns-exec /proc/$SERVER_PID/ns/net nc localhost 5000
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
<details>
<summary>
(click here to see the `listenAndServe()` implementation, or view the [full source here](https://github.com/rosenhouse/ns-mess/blob/master/c-demos/tcp-hello.c).)
</summary>
```c
#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>

const int listenPort = 5000;

void listenAndServe(char* message) {
  int listener = socket(AF_INET, SOCK_STREAM, 0);
  if (listener < 0) {
    perror("error: listenAndServe: opening socket");
    return;
  }

  int optval = 1; // allow port to be immediately re-used after process is killed
  setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, (const void *)&optval , sizeof(int));

  struct sockaddr_in serverAddr;
  bzero((char *) &serverAddr, sizeof(serverAddr));
  serverAddr.sin_family = AF_INET;
  serverAddr.sin_addr.s_addr = htonl(INADDR_ANY);
  serverAddr.sin_port = htons((unsigned short)listenPort);

  if (bind(listener, (struct sockaddr *) &serverAddr, sizeof(serverAddr)) < 0) {
    perror("error: listenAndServe: binding");
    return;
  }

  const int queueLength = 5;
  if (listen(listener, queueLength) < 0) {
    perror("error: listenAndServe: listen");
    return;
  }

  while (1) {
    struct sockaddr_in clientAddr;
    int clientlen = sizeof(clientAddr);
    int connection = accept(listener, (struct sockaddr *) &clientAddr, &clientlen);
    if (connection < 0) {
      perror("error: accept");
      return;
    }

    if (write(connection, message, strlen(message)) < 0) {
      perror("error: writing to socket");
      return;
    }

    close(connection);
  }
}
```
</details>


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

If you want to explore more, check out the [documentation for the `ip` utility](http://baturin.org/docs/iproute2/) (a.k.a. "iproute2"):

- Kick the tires on `ip netns pids` and `ip netns identify`.  Do they work when the threads are in different namespaces?
- Create a "virtual ethernet" pair using `ip link add`, then try to "connect one namespace to another" using `ip link set dev`.  Can you make a network connection (via `nc`) from one namespace to another?

Next time, we'll dive into Go language *goroutines*, what problems they solve and how they are different from threads.
