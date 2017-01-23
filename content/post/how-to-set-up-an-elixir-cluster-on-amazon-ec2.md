---
authors:
- benjamin
categories:
- Elixir
- Distributed
- Cluster
- Phoenix
- Edeliver
- Deployment
- Erlang
date: 2016-09-06T11:57:56+08:00
draft: false
short: |
  Learn how to set up an Elixir cluster and how to deploy a Phoenix application on Amazon EC2. The techniques outlined in this article can equally apply to other providers such as Digital Ocean and Linode. 
  
title: How to Set up a Distributed Elixir Cluster on Amazon EC2
---

Ask any Elixir aficionado "Why Elixir" and one of the answers that often comes up is "distribution". A possible definition of distribution is having multiple computers working together to perform some computation. In Elixir terms, it means having multiple _nodes_ connected in a _cluster_. Nodes are basically different Erlang runtimes that communicate with each other.

Setting up an Elixir cluster on your own machine or local area network (LAN) is usually pretty straightforward. I will show you how to set up a cluster on your own machine soon. What is slightly more challenging (read: fun!) is having the nodes talk to each other over the internet. In this case, you can have nodes that are geographically separated nodes communicating with each other.

I couldn't find a lot of resources on how to set up a geo-distributed cluster, or how to deploy Elixir/Phoenix apps. I didn't want to resort to something like Docker, because I wanted to see how far I could push Elixir and its tooling.

## Outline

This post outlines the steps I took in order to set up an Elixir cluster on Amazon EC2. However, you can most likely replicate these steps on another provider such as Digital Ocean or Linode.

> ### What about Heroku?
>
> Don't even bother trying to do distributed Elixir on Heroku. This is because of the way IP routing works within Heroku. There are ways to get around that, but it's not easy on the wallet. If you are running on a single node, Heroku could be an option. But that's not why you're reading this!

We will create a simple web application using the [Phoenix web framework](www.phoenixframework.org/), and then I will show you how to create a _release_, which is a way of packaging an Elixir application, followed by deploying the release across multiple servers.

##  Prerequisites

You are going to need the following installed:

* Elixir 1.3.x or later
* Phoenix 1.2.x or later
* More than one Amazon instance available

On each of the instances, you will need the following:

* Ubuntu 14.04 box. (You could use another distribution, but you would have to adapt the commands as we go along.)
* HA-Proxy 1.4.X should be installed on the server that the domain name is pointing to. 
* Git
* Elixir

This article assumes little Elixir and/or Phoenix knowledge. In fact, you can read this article and discover how much effort you would need to set up a distributed cluster in Elixir.

## Introduction to Distribution in Elixir

Some background to distributed Elixir is in order. When you run `iex`, or _interactive Elixir_, you are running a REPL (read eval print loop) in a single Erlang runtime. So opening more `iex` sessions mean that you are running each session in a separate runtime. By default, each of the runtimes cannot see nor talk to each other. You can run start each runtime in distributed-mode and the connect to other nodes. When a node joins another node, a cluster is formed. When a node succesfully connects to another node, that node becomes a member of the cluster. In other words, when Node E succesfully connects to Node A, it is automatically connected to Nodes A thru D: 

<img src="http://i.imgur.com/kyD5kBZ.png" width="100%" />

### Distribution on a Single Computer

Before we even mess with multiple nodes across multiple servers, it is helpful to see how we can run multiple nodes on a _single_ computer. In this example, we are going to create 3 nodes. These nodes are at first _not_ connected to each other. Let's create the first node:

```
% iex --sname barry
interactive elixir (1.3.2) - press ctrl+c to exit (type h() enter for help)
iex(barry@frankel)1>
```

`iex` is the interactive Elixir shell. The `--sname` flag stands for _short name_. It's short because we are omitting the hostname for now. This is followed by the name given to the node. `frankel`, shown in the prompt, is my host name. Let's spin up the next node:

```
% iex --sname maurice
interactive elixir (1.3.2) - press ctrl+c to exit (type h() enter for help)
iex(maurice@frankel)1>
```

And the final one:

```
% iex --sname robin
interactive elixir (1.3.2) - press ctrl+c to exit (type h() enter for help)
iex(robin@frankel)1>
```

Once again, the nodes _cannot_ see each other yet. Try this: Go to any node and list all the known nodes with `Node.list`:

```
iex(maurice@frankel)1> Node.list
[]
```

> Note: `Node.list` shows only the neighboring nodes, and _not_ the current node. To list the current node, use `node`.

As expected, we get an empty list. Time to build our cluster! Let's go to `barry` and try connecting to `robin`:

```
iex(barry@frankel)> Node.connect :robin@frankel
true
```

`true` means the connection attempt succeeded. Let's try `Node.list` again:

```
iex(barry@frankel)> Node.list
[:robin@frankel]
```

Woot! Now from `robin`, let's connect to `maurice`:

```
iex(robin@frankel)1> Node.connect :maurice@frankel
true
```

So far so good. Now what does `Node.list` show?

```
iex(robin@frankel)2> Node.list
[:barry@frankel, :maurice@frankel]
```

Sweet! `robin` is now connected to `barry` and `maurice`. But notice that we didn't explicitly connect `barry` and `maurice` together. Recall that you don't have to. In Elixir, once a node joins a cluster, _everyone can see everyone_. (There's something called _hidden_ nodes, but I'm pretending they don't exist.)

Don't take my word for it. On `maurice`:

```
iex(maurice@frankel)> Node.list
[:robin@frankel, :barry@frankel]
```

And on `barry`:

```
iex(barry@frankel)> Node.list
[:robin@frankel, :maurice@frankel]
```

### A Distributed Example with Chuck Norris

Let's do a fun example. We will perform a HTTP request on all 3 nodes. We will use the built-in HTTP client that comes with Erlang (yes, we can use the Erlang standard library in Elixir). We'll need to start the `inets` application on _all the nodes_. Instead of manually typing `inets.start` on all 3 nodes, we can do a `:rpc.multicall` that runs the function on all 3 nodes:

```
iex(barry@frankel)> :rpc.multicall(:inets, :start, [])
{[:ok, :ok, :ok], []}
```

Here's something that might not be immediately apparent. Even though the computation is performed on each individual node, the results are collected and presented on the _calling node_. In other words, when I make a HTTP request on `barry`, `barry` will get all the results. If you look at `maurice` and `robin`, you will _not_ see any output. 

Let's see this for real:

```
iex(barry@frankel)> :rpc.multicall(:httpc, :request, ['http://api.icndb.com/jokes/random'])
```

Here's an example output:

```
{[ok: {{'HTTP/1.1', 200, 'OK'},
   [...
   '{ "type": "success", 
      "value": { "id": 297, 
               "joke": "Noah was the only man notified before Chuck Norris relieved himself in the Atlantic Ocean.", "categories": [] } }'},
  ok: {{'HTTP/1.1', 200, 'OK'},
   [...,
   '{ "type": "success", 
      "value": { "id": 23, 
               "joke": "Time waits for no man. Unless that man is Chuck Norris.", "categories": [] } }'},
  ok: {{'HTTP/1.1', 200, 'OK'},
   [...,
   '{ "type": "success", 
      "value": { "id": 69, 
               "joke": "Scientists have estimated that the energy given off during the Big Bang is roughly equal to 1CNRhK (Chuck Norris Roundhouse Kick).", "categories": ["nerdy"] } }'}],
 []} 
```

Sweet! Now you know how to manually set up a cluster on a single host.

## Setting Up a Distributed Cluster

Here's brief overview on what we will accomplish:

1. We are going to configure a vanilla Phoenix application to be deploy-ready.
2. Install and configure the tools needed to perform the deployment.
3. Configure the individual nodes so that they can be part of the cluster.
4. Configure HA Proxy to load-balance between the ndoes.
5. Deploy!

This is what we want to achieve:

![](http://i.imgur.com/GreGmsO.png)

HA Proxy sits in front of the Elixir cluster. Each node lives on a server that is geographically separated. Whenever a HTTP request comes in, HA Proxy will, in a round robin fashion, pick one of the nodes to handle the request.

### Preparing your Phoenix application

It's time to configure the Phoenix application. These steps should be similar across most Phoenix applications.

#### Step 1: Add dependencies to `mix.exs`:

In order to prepare our Phoenix application for deployment, we will need to include [`exrm`](https://github.com/bitwalker/exrm) and [`edeliver`](https://github.com/boldpoker/edeliver). `exrm` is the Elixir release manager, which helps to automatically create a release. `edeliver` is a tool that helps with deployment. It is somewhat like [Capistrano](http://capistranorb.com/) if you come from the Ruby world.

> ### Exrm versus Distillery
>
> If you visit the `exrm` Github page you might notice the author pointing you to [Distillery](https://github.com/bitwalker/distillery). At this time of writing, I couldn't get it to work, therefore I stuck with `exrm`. Even so, the steps shouldn't change _that_ much.

```elixir
defmodule YourApp.Mixfile do
  use Mix.Project

  def project do
    [app: :your_app,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [mod: {YourApp, []},
     applications: [:phoenix, :phoenix_html, :cowboy, :logger, :gettext,
                    :exrm, :edeliver]] # <---
  end

  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  defp deps do
    [{:phoenix, "~> 1.1.4"},
     {:phoenix_html, "~> 2.4"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:gettext, "~> 0.9"},
     {:cowboy, "~> 1.0"},
     {:edeliver, "~> 1.4.0"}, # <--- 
     {:exrm, "~> 1.0.3"}]     # <---
  end
end 
```

Once you get the dependencies included, remember to install the dependencies:

```
% mix deps.get
```

#### Step 2: Configure `config/prod.exs`

Next, we need to configure the production environment. Open `config/prod.exs`

```elixir
use Mix.Config

config :your_app, YourApp.Endpoint,
  http: [port: 8080],                         # <--- 1
  url:  [host: "yourdomain.com", port: 80],   # <--- 2
  cache_static_manifest: "priv/static/manifest.json"

config :logger, level: :info
config :phoenix, :serve_endpoints, true       # <--- 3
import_config "prod.secret.exs"
```

Few things to note here:

1. Configure the `http` option to point to port `8080`.
2. Configure the `host` to whatever domain name you are using.
3. Make sure this line is _uncommented_. (This line is commented by default, and is _extremely_ easy to miss.)

> ### What does `config :phoenix, :serve_endpoints, true` do?
>
> This option is needed when you are doing an OTP releases (which you are). Turning this option on tells Phoenix to start the server for all endpoints. Otherwise, your web application will basically be inaccessible to the outside world.

### Configure Edeliver

Create a new `.deliver` folder under the root directory. In the `.deliver` folder, create the `config` file. Here's `.deliver/config` in its entirety:

``` shell
# 1. Give a name to your app

APP="your_app"

# 2. Declare the names of your servers and assign the public DNS

SG="ec2-1.2.3.4.compute.amazonaws.com"
US="ec2-3.4.5.6.compute.amazonaws.com"
UK="ec2-5.7.8.9.compute.amazonaws.com"

# 3. Specify a user 

USER="ubuntu"

# 4. Which host do you want to build the release on?

BUILD_HOST=$SG
BUILD_USER=$USER
BUILD_AT="/tmp/edeliver/$APP/builds"

# 5. Optionally specify the staging host

# STAGING_HOSTS=$SG
# STAGING_USER=$USER
# DELIVER_TO="/home/ubuntu"
 
#6. Specify which host(s) the app is going to be deployed to

PRODUCTION_HOSTS="$SG $US $UK"
PRODUCTION_USER=$USER
DELIVER_TO="/home/ubuntu"

#7. Point to the vm.args file

LINK_VM_ARGS="/home/ubuntu/vm.args"

#8. This is for Phoenix projects

# For *Phoenix* projects, symlink prod.secret.exs to our tmp source
pre_erlang_get_and_update_deps() {
  local _prod_secret_path="/home/$USER/prod.secret.exs"
  if [ "$TARGET_MIX_ENV" = "prod" ]; then
    __sync_remote "
      ln -sfn '$_prod_secret_path' '$BUILD_AT/config/prod.secret.exs'

      cd '$BUILD_AT'
      
      mkdir -p priv/static
      
      mix deps.get

      npm install
      
      brunch build --production
      
      APP='$APP' MIX_ENV='$TARGET_MIX_ENV' $MIX_CMD phoenix.digest $SILENCE
    "
  fi
}
```

Let's go through the file according to each of the numbered comments:

### 1. Give a name to your app

Specify a name for your app. This is the name of the directory on the server containing the application.

### 2. Declare the names of your servers and assign the public DNS

Here I have named the servers based on their geographical location. You can pick your own naming scheme. Note that you should be using the _Public DNS_, because this resolves to the public IP address or Elastic IP address of the instance. This means that even if the virtual machine somehow reboots and gets assigned a new private IP, the public IP will remain unchanged:

<img src="http://i.imgur.com/bsfg9wz.png" width="100%" />

### 3. Specify a user 

This is the user that has SSH and folder access on each of the previously declared servers. Note that all the servers should have the same user name.

### 4. Specify the host to build the release on

I usually point this to the server that is closest to me.

> ### Why do I even need to build the release on a remote server?
>
> Some OS specific libraries are required. This means that when you build a release on say, a Mac, and then transfer the release to a Linux system, nothing will work and you will most definitely get strange and utterly confusing errors.

### 5. Optionally specify the staging host

You can also specify a staging host if you wish. The staging host is basically the host where you want to test the release at. I didn't bother with this step therefore this part is commented out.

### 6. Specify which host(s) the app is going to be deployed to

`PRODUCTION_HOSTS` specifies the production hosts. Each host is separated by a space.

### 7. Point to the vm.args file

`LINK_VM_ARGS` specifies the path to the `vm.args` file. As its name suggests, this file specifies the flags used to start the Erlang virtual machine. We will configure this file soon.

### 8. Prepare the Phoenix application

This function runs a few commands that prepare the Phoenix application. These commands perform tasks such as installing the necessary dependencies, and perform asset compilation.

## Configuring the Nodes

You will need to create 3 files and have them sit in the `/home/ubuntu` (or `/home/$USER`) folder in each host. Now we need to create three copies of `vm.args`. In this example, we'll have _one_ copy for each server:

#### SG

```shell
-name sg@ec2-1.2.3.4.compute.amazonaws.com
-setcookie s3kr3t
-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9155
-config /home/ubuntu/your_app.config
```

#### US

```shell
-name us@ec2-3.4.5.6.compute.amazonaws.com
-setcookie s3kr3t
-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9155
-config /home/ubuntu/your_app.config
```

#### UK

```shell
-name uk@ec2-5.6.7.8.compute.amazonaws.com
-setcookie s3kr3t
-kernel inet_dist_listen_min 9100 inet_dist_listen_max 9155
-config /home/ubuntu/your_app.config
```

Here's what each of the flags mean:

* `name`: The name of the node. This is the "long name" version, which includes the domain.
* `setcookie`: The Erlang VM relies on a cookie to determine if a node can join a cluster or not.
* `kernel`: This specifies the range of ports that the Erlang distribution protocol uses. You'll need to specify this because we will have to manually open the ports later.
* `config`: This specifies the path to the file that contains configuration of the neighboring nodes.

We'll cover the `your_app.config` file next. As with `vm.args`, we need to create three copies of `your_app.config`.

`sync_nodes_optional` specifies the list of nodes that are _not_ required for the current node to start. This means that the node will connect to the list of nodes and will wait for `sync_nodes_timeout` milliseconds. In the case of a timeout, it will simply continue starting itself.

#### SG

```erlang
[{kernel,
  [
    {sync_nodes_optional, ['us@ec2-3.4.5.6.compute.amazonaws.com', 
                           'uk@ec2-5.7.8.9.compute.amazonaws.com']},
    {sync_nodes_timeout, 30000}
  ]}
].
```

#### US

```erlang
[{kernel,
  [
    {sync_nodes_optional, ['sg@ec2-1.2.3.4.compute.amazonaws.com', 
                           'uk@ec2-5.7.8.9.compute.amazonaws.com']},
    {sync_nodes_timeout, 30000}
  ]}
].
```

#### UK 

```erlang
[{kernel,
  [
    {sync_nodes_optional, ['sg@ec2-1.2.3.4.compute.amazonaws.com', 
                           'us@ec2-3.4.5.6.compute.amazonaws.com']},
    {sync_nodes_timeout, 30000}
  ]}
].
```

> ### `your_app.config` looks weird!
>
>
> You might think that `your_app.config` looks like a strange version of JSON. However, the contents `your_app.config` are in fact valid _Erlang_ code. Congratulations! You are an Erlang programmer!

> ### Is there a `sync_nodes_mandatory`?
>
> Why, yes! As you might guess, the node will wait for `sync_nodes_timeout` milliseconds. If no connections are made, or if one of the connection fails, the node will not start. It is entirely possible to mix `sync_nodes_optional` and `sync_nodes_mandatory`.

#### prod.secret.exs

The last file to create is `prod.secret.exs`. The minimum that you should have is this:

```elixir
use Mix.Config
```

You can add production specific credentials to this file, which you shouldn't commit into source control. Since we don't have any at the moment, this file is a one liner.

### Configuring Amazon EC2

The only thing that you need to configure for Amazon EC2 is which ports are open in the Security Groups used by your instances.

Ports for:

* Phoenix: `8080`
* Erlang Port Mapper Daemon (epmd): `4369` 
* Distributed communication: `9100-9155`

You might recall that port `8080` was configured previous in `config/prod.exs`, while the port range of `9100-9155` was specified in `vm.args`. Here's an example:

<img src="http://i.imgur.com/n2CW4PH.png" width="100%" />

> ### Lock Down the Source IPs!
>
> In the screenshot, the sources are all listed as `0.0.0.0/0`. You should specify the sources as the IPs of the other nodes in the cluster.

### HA Proxy

Now we configure HA Proxy. Assuming you have it installed, open/create the following file as the root user:

```shell
% sudo vim /etc/haproxy/haproxy.cfg
```

The file will look something like this:
 
```
global
    log 127.0.0.1 local0 notice
    maxconn 2000
    user haproxy
    group haproxy

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option redispatch
    timeout connect 10000
    timeout client  20000
    timeout server  20000

listen your-app-name 0.0.0.0:80
    mode http
    stats enable
    stats uri /haproxy?stats
    stats realm Strictly\ Private
    stats auth admin:sekret
    option forwardfor
    option http-server-close
    balance roundrobin
    option httpclose
    server sg 1.2.3.4:8080 check
    server us 3.5.7.9:8080 check
    server uk 5.7.8.9:8080 check
```

The last three lines are the most important. You can always tweak the settings later.

> ### Do not copy the above file wholesale!
>
> There are some things which you need to configure on your own. For example, the `stats auth` option, which allows you to access HA Proxy's admin panel. You can also experiment with the various `balance` values. For example, you can setup HA Proxy to pick the server based on the location of the incoming IP address.

## Deploy, deploy!

After all that hard work, all that's left to do is the deploying:

```
% git push && mix edeliver update production --branch=master --start-deploy
```

After pushing the updated changes to `git`, the next command builds the release, deploys them to each of the production hosts, and finally starts the app on each of the hosts in one go. If everything goes well, this is what you should see:

``` shell
EDELIVER YOUR_APP WITH UPDATE COMMAND

-----> Updating to revision 1721f31 from branch master
-----> Building the release for the update
-----> Authorizing hosts
-----> Ensuring hosts are ready to accept git pushes
-----> Pushing new commits with git to: ubuntu@ec2-1-2-3-4.compute.amazonaws.com
-----> Resetting remote hosts to 3721f31b6acd3459d4f9c3ee6dc38b2bdad1f839
-----> Cleaning generated files from last build
-----> Fetching / Updating dependencies
-----> Compiling sources
-----> Detecting exrm version
-----> Generating release
-----> Copying release 0.0.1 to local release store
-----> Copying your_app.tar.gz to release store
-----> Deploying version 0.0.1 to production hosts
-----> Authorizing hosts
-----> Uploading archive of release 0.0.1 from local release store
-----> Extracting archive your_app_0.0.1.tar.gz
-----> Starting deployed release

UPDATE DONE!
```

![](http://i.imgur.com/n8IcOoD.png)

## Where to learn more

* [Edeliver](https://github.com/boldpoker/edeliver)
* [exrm](https://github.com/bitwalker/exrm)
* [Erlang Distribution Protocol](http://erlang.org/doc/apps/erts/erl_dist_protocol.html)
* [Phoenix Deployment](http://www.phoenixframework.org/v0.13.1/docs/deployment)
* [Running Elixir and Phoenix projects on a cluster of nodes](https://dockyard.com/blog/2016/01/28/running-elixir-and-phoenix-projects-on-a-cluster-of-nodes)
* [The Little Elixir and OTP Guidebook](http://www.manning.com/tanweihao?a_aid=exotpbook&a_bid=99f537ec) (I wrote this!)

## Conclusion

Getting the nodes to communicate with each other in Elixir is not that hard at all. However, creating a release and deploying it to multiple hosts is tricky. Like all things deployment related, once you get a working setup, everything becomes pretty smooth sailing.

## Acknowledgments

Thanks to Pivotal for letting me work on this. Mike Mazur, Gabe Hollombe, and Alan Yeo for proof-reading this and giving lots of constructive feedback. And thank you for taking the time to read this!


