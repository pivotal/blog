+++
authors = ["dgriffith"]
categories = ["Elixir", "Cloud Foundry"]
date = "2017-08-20T14:11:20+10:00"
draft = false
image = ""
short = "A tutorial for configuring an Elixir application to automatically cluster on Cloud Foundry (eg. PWS) using container to container networking.\n"
title = "Elixir Clustering And Discovery On Cloud Foundry"

+++

## Motivation

The Erlang Virtual Machine (BEAM) and subsequently the Elixir Programming Language which runs on it are designed for building highly concurrent systems. The language primitives offer support for concurrency that can easily be used for executing code on remote machines. As such this platform is often used for building distributed systems (eg. Riak). [The Phoenix web framework](http://phoenixframework.org/), for example, uses this feature of Erlang/Elixir to publish messages across nodes and push those to all [clients connected via websockets](https://hexdocs.pm/phoenix/channels.html). These distributed systems made up of "nodes" form clusters and communicate via Erlang messaging, but in order to do this they need to be able to discover and "connect" to each other via TCP. Once connected they are able to send messages between processes running across nodes as easily as between processes running on different nodes.

Cloud Foundry's new Container to Container networking (C2C) feature now enables for application with these kinds of architectures to run on Cloud Foundry.

## Objective

We want to be able to deploy a multi node Elixir application to Cloud Foundry and have it automatically cluster using Erlang networking. This post will show you how to accomplish this making use of Cloud Foundry's Container to Container networking (C2C) as well as how to enable automatic cluster formation and healing. We make use of the [Netflix Eureka Service Registry](https://github.com/Netflix/eureka) which can be easily configured on all Pivotal Cloud Foundry instances. We will deploy a simple application to PWS to demonstrate all these parts. For simplicity this tutorial will just use an Elixir app created by Mix, but if you're using a phoenix application most of this should still work.

For the rest of this post we assume you have [Elixir Lang](https://elixir-lang.org/) installed and running on your system. As well as the [cf cli](https://github.com/cloudfoundry/cli) and are already signed into a CF instance. You can [sign up for PWS for a free trial to follow along](http://run.pivotal.io/).

All of the code we use in this tutorial can be found [in this repo](https://github.com/DylanGriffith/my-clustered-app)

## Create The App

We can create our Elixir app with mix:

```bash
$ mix new --sup my_clustered_app
```

Then:

```bash
$ cd my_clustered_app
```

Now your app is created we want to add an HTTP route which will be used to view the clustered nodes.

Firstly we'll need to add few dependencies. We'll use [cowboy](https://github.com/ninenines/cowboy) for the web server, [plug](https://github.com/elixir-plug/plug) for routing and [poison](https://github.com/devinus/poison) for JSON parsing. Update your `mix.exs` file like so:

```elixir
defp deps do
  [
    {:cowboy, "~> 1.0.0"},
    {:plug, "~> 1.0"},
    {:poison, "~> 3.1"},
  ]
end
```

Then install the new dependencies:

```bash
$ mix deps.get
```

Add a file at `lib/my_clustered_app/router.ex`:

```elixir
defmodule MyClusteredApp.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    response = %{
      current_node: :erlang.node,
      connected_nodes: :erlang.nodes
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(201, Poison.encode!(response))
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
```

Then you will need to update the start function in your `lib/my_clustered_app/application.ex` to start your web server:

```elixir
def start(_type, _args) do
  import Supervisor.Spec, warn: false

  port = elem(Integer.parse(System.get_env("PORT")), 0)
  children = [
    Plug.Adapters.Cowboy.child_spec(:http, MyClusteredApp.Router, [], [port: port]),
  ]

  opts = [strategy: :one_for_one, name: MyClusteredApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Now start your app using:

```bash
$ PORT=4001 mix run --no-halt
```

Then open your web browser to http://localhost:4001/ and you'll see the JSON response. You can see here the name of the node that served the response which should be `"nonode@nohost"` as well as the names of the other nodes in the cluster which will be empty for now.

## Deploy It To Cloud Foundry

First step for deploying to Cloud Foundry we'll need to add a `manifest.yml`. You should use the following but you'll probably want to change the `host` to avoid conflicting with the one I've already created:

```yaml
---
applications:
  - name: my-clustered-app
    host: changeme-clustered-app
    instances: 4
    memory: 1G
    buildpack: https://github.com/HashNuke/heroku-buildpack-elixir.git
    command: elixir --name app$CF_INSTANCE_INDEX@$CF_INSTANCE_INTERNAL_IP -S mix run --no-halt
```

NOTE: I've used 1G memory here because the app seems to use a lot of memory on startup but I haven't investigated why. After the app gets started it only seems to use around 80MB.

Then deploy the app to Cloud Foundry:

```bash
$ cf push
```

Once the app is deployed we should be able to visit it in our browser. If you deployed to PWS your URL will look like https://changeme-clustered-app.cfapps.io

Since we've configured 4 instances of our application Cloud Foundry should be routing our requests to different nodes each request. If you refresh the browser several times you should notice that you're connecting to different nodes by looking at the `current_node`.

NOTE: If you run into issues with deploying because of a mismatch with elixir version in your `mix.exs` you have two options. The best option is probably to configure the elixir buildpack to run the same version of Elixir as you're running locally. To figure that out run:

```bash
$ elixir --version
```

Then configure the buildpack by creating a file in the root directory of your app called `elixir_buildpack.config` with the following content for example:

```
elixir_version=1.5.1
```

After that you can `cf push` again and see the issue should be fixed.

Alternatively you can just update the version in your `mix.exs` file but it may not be compatible depending on the version you used to generate your project.

## Configure It To Automatically Cluster

In order to do self discovery for our application we'll need to create and bind the service registry service to our application:

```bash
$ cf create-service p-service-registry standard service-registry
```

You'll now need to wait a few minutes for Cloud Foundry to finish setting up the service. Feel free to grab a coffee here. You can check the status by running:

```bash
$ cf services
```

You want to wait until it says `create succeeded` next to your service.

Once it is finished you can bind it to your application:

```bash
$ cf bind-service my-clustered-app service-registry
```

Now since we'll be making use of the new C2C feature in Cloud Foundry we'll need to install the [network-policy plugin](https://github.com/cloudfoundry-incubator/cf-networking-release) if you don't already have it installed:

```bash
$ cf install-plugin -r CF-Community network-policy
```

Now that we have the plugin installed we can configure some access rules to allow network access between our nodes on Cloud Foundry:

```bash
$ cf allow-access my-clustered-app my-clustered-app --protocol tcp --port 4369
$ cf allow-access my-clustered-app my-clustered-app --protocol tcp --port 9001
```

Erlang uses port 4369 for running epmd and we will configure our application to use port 9001 for erlang communication. Update your `manifest.yml` like so:

```yaml
---
applications:
  - name: my-clustered-app
    host: changeme-clustered-app
    instances: 4
    memory: 1G
    buildpack: https://github.com/HashNuke/heroku-buildpack-elixir.git
    command: elixir --name app$CF_INSTANCE_INDEX@$CF_INSTANCE_INTERNAL_IP --cookie secret-cookie --erl "-kernel inet_dist_listen_min 9001 inet_dist_listen_max 9001" -S mix run --no-halt
```

NOTE: While Cloud Foundry networking security will mean your Erlang nodes should not be accessible via Erlang networking unless you allow explicit access you still may wish to update the cookie in the above configuration for additional security. For even more security you probably want to set an environment variable for your node and use that instead of hard-coding it.

For maintaining the cluster we're going to use the popular [libcluster library](https://github.com/bitwalker/libcluster) along with a [plugin strategy built for Cloud Foundry and Eureka](https://github.com/DylanGriffith/libcluster-cloud-foundry).

You can install them by adding them to your `mix.exs` file like so:

```elixir
defp deps do
  [
    {:cowboy, "~> 1.0.0"},
    {:plug, "~> 1.0"},
    {:poison, "~> 3.1"},
    {:libcluster, "~> 2.1"},
    {:libcluster_cloud_foundry, git: "https://github.com/DylanGriffith/libcluster-cloud-foundry.git"},
  ]
end
```

You'll then need to configure libcluster to use the cloudfoundry strategy in `config/prod.exs`:

```elixir
use Mix.Config

config :libcluster,
  topologies: [
    cf_clustering: [
      strategy: Cluster.Strategy.CloudFoundryEureka,
      config: [
      ]
    ]
  ]
```

In order for this to work you'll need to uncomment the line in your `config/config.exs`:

```elixir
import_config "#{Mix.env}.exs"
```

And add a `config/dev.exs` and `config/test.exs`:

```bash
$ touch config/dev.exs config/test.exs
```

Add the following to both those files:

```elixir
use Mix.Config
```

Now deploy your app again:

```bash
$ cf push
```

After the deployment finishes you should be able to visit your app again in the browser and see the connected nodes appearing.


## Summary

In summary we've managed to deploy a multi-instance Elixir application to Cloud Foundry and have the nodes automatically discover and connect to each other. These clustered nodes will now be able to send messages between processes and execute code on remote nodes.

All of the code we used in this tutorial can be found [in this repo](https://github.com/DylanGriffith/my-clustered-app)

The [clustering strategy](https://github.com/DylanGriffith/libcluster-cloud-foundry) makes use of the [Service Registry](https://console.run.pivotal.io/marketplace/services/dfb4bee2-c56a-4257-93c4-0499e35637b3) tile available on all Pivotal Cloud Foundry instances. This will poll the service registry every 10 seconds to register the current instance and discover then connect to the other registered instances.

You can find more examples on how to use C2C networking on the [cf-networking-release repo](https://github.com/DylanGriffith/libcluster-cloud-foundry).
