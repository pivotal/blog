---
authors:
- chendrix
- jzarrabi
categories:
- Concourse
- Docker
- Ruby
- Containerization
date: 2016-12-15T13:50:20-08:00
draft: false
short: |
  Sometimes we want to create custom docker images with external dependencies cached. Learn how to have Concourse automate this and use the built container to run tests.
title: Using docker-image-resource to build a custom container for testing your Ruby apps in Concourse
---
## What you will learn by the end of this

* How to build a container using the `docker-image-resource`
* How to use a built container as the `image` for later tasks in your pipeline


## Who this is for

* You are used to building simple Concourse pipelines
* You want to learn more about the `docker-image-resource`


## What you'll need

* A running Concourse instance (we have tested it against 2.5.1)
* A Dockerhub account


## The Problem

We have an example Ruby app we are testing in Concourse called [flight-school](https://github.com/concourse/flight-school).

This is our current pipeline configuration:

~~~~yaml
---
resources:
- name: flight-school
  type: git
  source:
    uri: https://github.com/concourse/flight-school
    branch: master

jobs:
- name: test
  plan:
  - get: flight-school
  - task: run-tests
    config:
      platform: linux
      image_resource:
        type: docker-image
        source:
          repository: ruby
      inputs:
      - name: flight-school
      run:
        path: /bin/bash
        args:
        - -c
        - |
          cd flight-school
          bundle install
          bundle exec rspec
~~~~


While this works and makes for a small pipeline, it causes a few problems.

* Concourse has to download the gems each time `run-tests` is run.

* The gem versions may be different between each build of `test`.

    Let's say we have pinned our Sinatra gem at `~> 1.4`. During build 3 of `test`, Concourse fetched version `1.4.0` of Sinatra. Now a new version `1.4.1` of Sinatra is pushed. If I were to re-run `test`, build number 4 would fetch `1.4.1`.

* It is not easily scalable.

    We have to copy the `bundle install` code around everywhere we want to run tests.


## The Proposed Solution

If we can create a container with the gems required for flight-school pre-installed, we can use that container as the environment for all of our ruby tests.

* Because Concourse caches resources (including Docker images), we only need to download and install gems when we rebuild the container, i.e. when new versions of flight-school are released.
* Because the gems are built into the container, they are not changed between runs of a job, thus we have reproducibility.
* Because we have pre-fetched the gems, we no longer need to run `bundle install` before running tests.


## Creating a Docker container

If we were attempting to build this Docker image on a local workstation, we might have a workspace that looks like this:

~~~~no-highlight
.
├── Dockerfile
└── flight-school
    ├── Gemfile
    ├── Gemfile.lock
    ├── LICENSE
    ├── NOTICE.md
    ├── README.md
    ├── config.ru
    ├── lib
    │   ├── app.rb
    │   ├── radar.rb
    │   └── views
    │       ├── airport.erb
    │       ├── index.erb
    │       └── no_airport.erb
    ├── manifest.yml
    └── spec
        ├── examples.txt
        ├── fixtures
        │   ├── edi
        │   └── jfk
        ├── integration_spec.rb
        ├── radar_spec.rb
        └── spec_helper.rb
~~~~

with a `Dockerfile`:

~~~dockerfile
FROM ruby

ADD flight-school /tmp/
RUN bundle install --gemfile=/tmp/flight-school/Gemfile
RUN rm -rf /tmp/flight-school
~~~

This adds the flight-school repository to `/tmp`, uses its `Gemfile` to `bundle install`, and removes the repository from the container, creating the perfect environment to run the flight-school tests in.

We could run `docker build .` from this workspace to get our container, and then `docker push` to put it online, but that is slow and boring! We want to automate this process and have Concourse do it for us.


## Automating container creation using the docker-image-resource

In Concourse we have the [`docker-image-resource`](https://github.com/concourse/docker-image-resource). It builds an image defined by a `Dockerfile` inside of a workspace, and then pushes that image to a Dockerhub repository for later use.

We first define the docker-image-resource we will use in the pipeline by specifying our Dockerhub information.

~~~~yaml
- name: flight-school-docker-image
  type: docker-image
  source:
    repository: <your-dockerhub-repo>/flight-school-example
    username: {{dockerhub-username}}
    password: {{dockerhub-password}}
~~~~

To use this resource to build the image we want, we have to provide it a workspace that matches the one we were using locally earlier.

### Writing a Concourse task to create our workspace

We start by defining a new Concourse task to create the workspace needed to build our image.

This task will generate an output called `workspace` which has the same directory structure we constructed earlier: a Dockerfile at `./Dockerfile` and a copy of flight-school at `./flight-school`.

Our task configuration:

~~~~yaml
platform: linux
image_resource:
  type: docker-image
  source:
    repository: ubuntu

outputs:
- name: workspace

inputs:
- name: flight-school

run:
  path: /bin/bash
  args:
  - -c
  - |
    output_dir=workspace

    cat << EOF > "${output_dir}/Dockerfile"
    FROM ruby

    ADD flight-school /tmp/flight-school
    RUN bundle install --gemfile=/tmp/flight-school/Gemfile
    RUN rm -rf /tmp/flight-school
    EOF

    cp -R ./flight-school "${output_dir}/flight-school"
~~~~

### Using our task to build the image

We can now hook up our task into a job which builds and pushes our image. All we have to do is hook up our task's `workspace` output to a `put` of our docker-image-resource and we should have a ready to go image on Dockerhub.

Our job configuration:

~~~~yaml
- name: build-cached-image
  plan:
  - get: flight-school
  - task: build-cached-image
    config:
      platform: linux
      image_resource:
        type: docker-image
        source:
          repository: ubuntu

      outputs:
      - name: workspace

      inputs:
      - name: flight-school

      run:
        path: /bin/bash
        args:
        - -c
        - |
          output_dir=workspace

          cat << EOF > "${output_dir}/Dockerfile"
          FROM ruby

          ADD flight-school /tmp/flight-school
          RUN bundle install --gemfile=/tmp/flight-school/Gemfile
          RUN rm -rf /tmp/flight-school
          EOF

          cp -R ./flight-school "${output_dir}/flight-school"

  - put: flight-school-docker-image
    params:
      build: workspace

~~~~

We can visualize it as a mini-pipeline

{{< responsive-figure src="/images/concourse-docker-image-resource-cache-tutorial/build-cached-image-job.png" alt="Build Cached Image Job Visualization" >}}

## Using the built image to run our tests

At this point, we have an image on Dockerhub that has our ruby gems installed onto it. In order to run our tests inside of it, we simply need to call a `get` on flight-school-docker-image, and then use that as the `image` of our run-tests task.

Our test job now looks like:

~~~~yaml
- name: test
  plan:
  - get: flight-school-docker-image
    passed: [build-cached-image]
    trigger: true
  - get: flight-school
    passed: [build-cached-image]
  - task: run-tests
    image: flight-school-docker-image
    config:
      platform: linux
      inputs:
      - name: flight-school
      run:
        dir: flight-school
        path: bundle
        args:
        - exec
        - rspec
~~~~


## Putting it all together

Our final pipeline now looks like:

~~~~yaml
resources:
- name: flight-school
  type: git
  source:
    uri: https://github.com/concourse/flight-school
    branch: master

- name: flight-school-docker-image
  type: docker-image
  source:
    repository: <your-dockerhub-repo>/flight-school-example
    username: {{dockerhub-username}}
    password: {{dockerhub-password}}

jobs:
- name: build-cached-image
  plan:
  - get: flight-school
  - task: build-cached-image-workspace
    config:
      platform: linux
      image_resource:
        type: docker-image
        source:
          repository: ubuntu

      outputs:
      - name: workspace

      inputs:
      - name: flight-school

      run:
        path: /bin/bash
        args:
        - -c
        - |
          output_dir=workspace

          cat << EOF > "${output_dir}/Dockerfile"
          FROM ruby

          ADD flight-school /tmp/flight-school
          RUN bundle install --gemfile=/tmp/flight-school/Gemfile
          RUN rm -rf /tmp/flight-school
          EOF

          cp -R ./flight-school "${output_dir}/flight-school"

  - put: flight-school-docker-image
    params:
      build: workspace

- name: test
  plan:
  - get: flight-school-docker-image
    passed: [build-cached-image]
    trigger: true
  - get: flight-school
    passed: [build-cached-image]
  - task: run-tests
    image: flight-school-docker-image
    config:
      platform: linux
      inputs:
      - name: flight-school
      run:
        dir: flight-school
        path: bundle
        args:
        - exec
        - rspec
~~~~


## Final Thoughts

We just used the `docker-image-resource` to build a container that is then used as the environment in which we run our tests.

Hopefully this gives you a better understanding of how the `docker-image-resource` can be leveraged to create more efficient and reproducible jobs.
