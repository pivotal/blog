---
authors:
- forde
categories:
- Docker
- Cloud Foundry
date: 2017-06-12T11:40:22Z
draft: false
short: |
  Pushing a Docker Registry to Cloud Foundry can be a powerful approach
  to distributing private Docker images to teams with minimal overhead.
title: Deploying a Docker Registry to Cloud Foundry
image: /images/cloud-foundry-docker-registry/registry.png
---

{{< responsive-figure src="/images/cloud-foundry-docker-registry/registry.png" class="center">}}

For one of our projects, there was a requirement to run a small private [Docker Registry](https://docs.docker.com/registry/). As always, we were looking for a solution that is robust with minimal overhead. Looking at the [source code for the Registry](https://github.com/docker/distribution), you can quickly see that it’s a Go application. As it turns out, we have [Cloud Foundry](https://www.cloudfoundry.org/platform/) which is great at running applications. Looks like it's a good match, so let’s get started!


# Compiling for the Cloud

Cloud Foundry has a [Binary Buildpack](https://github.com/cloudfoundry/binary-buildpack) which is perfect for Go applications. As long as you have a compiled binary, you can ```cf push``` and have it running in seconds. The Docker Registry is open source under the [docker/distribution](https://github.com/docker/distribution) Github repository.

~~~bash
$ cd $(echo $GOPATH)
$ git clone https://github.com/docker/distribution.git src/github.com/docker/distribution
Cloning into 'src/github.com/docker/distribution'...
~~~

The repository shows a Makefile with everything we need to build and compile the binaries for the application. All we need now is the right environment to compile binaries for the Binary Buildpack. Opening [the docs](https://docs.cloudfoundry.org/buildpacks/binary/index.html) reveals that it prefers binaries compiled for cflinuxfs2 or lucid64 root filesystems, and a Docker image is provided.

Creating the local Docker container is easy with the help of [docker-machine](https://docs.docker.com/machine/).

~~~bash
$ docker-machine start dev
Starting "dev"...
...
Started machines may have new IP addresses. You may need to re-run the `docker-machine env` command.
$ eval $(docker-machine env dev)
$ docker run -itv /Users/dwayne.forde/workspace/src/go/src/:/app/src cloudfoundry/cflinuxfs2
~~~

Now that we’re in the container, we need to install a newer version of Go.

~~~bash
$ cd ~
$ wget https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz
Saving to: 'go1.8.3.linux-amd64.tar.gz'
$ tar -zxf go1.8.3.linux-amd64.tar.gz
$ mv go /usr/local
$ export GOPATH=/app
$ export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
~~~

Then compile.

~~~bash
$ cd /app/src/github.com/docker/distribution/
$ make
+ fmt
+ vet
+ lint
+ build
…
+ test
…
+ /home/vcap/app/src/github.com/docker/distribution/bin/registry
+ /home/vcap/app/src/github.com/docker/distribution/bin/digest
+ /home/vcap/app/src/github.com/docker/distribution/bin/registry-api-descriptor-template
+ binaries
~~~

Once this finishes, you can check the ```bin``` directory for the new Registry binary, then leave the container.

~~~bash
$ ./bin/registry

Usage:
  registry [flags]
  registry [command]

Available Commands:
  serve           `serve` stores and distributes Docker images
  garbage-collect `garbage-collect` deletes layers not referenced by any manifests
  help            Help about any command

Flags:
  -h, --help=false: help for registry
  -v, --version=false: show the version and exit


Use "registry help [command]" for more information about a command.

$ exit
~~~

# Configure for Success

The last step is to push the binary to Cloud Foundry. The Registry requires a [configuration file](https://docs.docker.com/registry/configuration/) to configure most things like the listening ```address:port```. Since we don't want make any port assumptions, we’ll need to have a way to inject the value at runtime.

We can take advantage of the [environment variable provided](https://docs.cloudfoundry.org/devguide/deploy-apps/routes-domains.html#http-vs-tcp-routes) to Cloud Foundry app containers. To do this, we can make a small configuration template, start script, and the Procfile required by the buildpack.

~~~bash
$ cd src/github.com/docker/distribution/bin
~~~
~~~yaml
#config.yaml.template
version: 0.1
storage:
    cache:
        layerinfo: inmemory
    filesystem:
        rootdirectory: /tmp
http:
    addr: :PORT
~~~
~~~bash
#start.sh
#!/bin/bash

set -e

sed "s/PORT/$PORT/" config.yml.template > config.yml

echo "Docker Registry port set to ${PORT}."

./registry serve config.yml
~~~
~~~yaml
#Procfile
web: ./start.sh
~~~

Now we have everything needed to run the application on Cloud Foundry.

# Test Run

Once you've logged into Cloud Foundry and are in the target organization and space.

~~~bash
$ cf push registry-test -b binary_buldpack
     state     since                    cpu    memory    disk      details
#0   running   2017-06-07 09:46:19 PM   0.0%   0 of 1G   0 of 1G
~~~

Let’s check the [catalogue](https://docs.docker.com/registry/spec/api/#catalog) in the Registry, push a small image, and check again.

~~~bash
$ curl registry-test.cfapps.io/v2/_catalog
{}
$ docker pull alpine
$ docker tag alpine registry-doom.cfapps.io/alpine
$ docker push registry-test.cfapps.io/alpine
$ curl registry-test.cfapps.io/v2/_catalog
{"repositories":["alpine"]}
~~~

That’s it! This means we can scale a Docker Registry as demands grow and also continue to ```cf push``` for as many teams that are in need within minutes. Further configuration can include things like authorization, storage (important since app container storage is ephemeral), etc so explore the [configuration options](https://docs.docker.com/registry/configuration/) in order to use this approach to its full potential.
