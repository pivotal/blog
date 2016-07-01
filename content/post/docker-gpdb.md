---
authors:
- lucas
categories:
- GPDB
- Docker
date: 2016-06-22T13:24:13-07:00
draft: false
short: |
 A look into how the GPDB R&D team uses Docker to increase development consistency. 
title: Running GPDB using Docker
---

Compiling in different environments is an incredibly frustrating hurdle in the development process. To combat this, the GPDB R&D team uses Docker to improve workflow speed and consistency. Docker pushes for a standard compilation environment for GPDB users, sidestepping the compilation confusions that often pop up. Through Docker, the GPDB R&D team synchronizes after the development stage and easily compares results in the Docker-run environment. Testing is also expedited due to the consistent and streamlined nature of Docker. | [What is Docker?](https://www.docker.com/what-docker) | [Basic Overview](http://www.troubleshooters.com/linux/docker/docker_newbie.htm) |

## Getting Started with Docker
Docker is composed of three core elements: dockerfiles, images, and containers. A dockerfile provides command-line instructions which are used to build an image. An image is a collection of root filesystem changes and the corresponding execution parameters for use in runtime [[1]](https://docs.docker.com/engine/reference/glossary/#image), and is read-only. Finally, a container is the stateful instance of an image [[2]](https://docs.docker.com/engine/reference/glossary/#container). GPDB runs inside the container, but is compiled when the image is constructed. The GPDB dockerfile, the initial piece of the puzzle, was recently added to master, so it is easier than ever to get Docker and GPDB running.

### Step 1: Gather Resources
Two important tools are needed to run GPDB on Docker: Docker and VirtualBox. VirtualBox manages virtual machines, which is where we will run our instance of GPDB. Detailed installation guides are on their websites. 

> Downloads: [Docker](https://docs.docker.com/mac/) | [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

We also need a Github repository: [GPDB Master](https://github.com/greenplum-db/gpdb). This repo contains the GPDB source files in addition to the dockerfile. There is also a GPDB Dockerhub repository, found [here](https://hub.docker.com/r/pivotaldata/gpdb-devel/). The following commands clone and update GPDB master, but feel free to employ your own Git routine for these steps.

~~~bash
# Clone
git clone git@github.com:greenplum-db/gpdb.git

# Update
git fetch --all
git checkout -b [BRANCH_NAME]
git pull --rebase origin master
~~~

### Step 2: Create your virtual environment
In order to create a Docker container, inside of which we will run an instance of the database, we need to create a virtual space for our container to go into. We can do so through VirtualBox. In this step, make sure not to over-allocate resources.

~~~bash
# Create virtual machine
docker-machine create -d virtualbox --virtualbox-cpu-count 2 --virtualbox-disk-size 50000 --virtualbox-memory 4096 gpdb

# Set environment variables for Docker
eval $(docker-machine env gpdb)
~~~

### Step 3: Build and run the Docker image
We will use the dockerfile to build an image. Note that when we build, GPDB will compile and install. Beforehand, we need to update submodules. After entering the run command, we will immediately be inside of the container. 

> If you run into an error, you may need to add "RUN yum -y install wget" to /docker/base/dockerfile. Also, you may need to be connected to ethernet.

~~~bash
# Update submodules
git submodule update --init --recursive

# Build Docker image
docker build -t pivotaldata/gpdb-devel -f ./docker/base/Dockerfile .

# Run Docker image
docker run -it pivotaldata/gpdb-devel
~~~

### Step 4: Starting GPDB
Now that we are inside of the container, we are able to work with the database itself. We do not need to compile GPDB because it was already done for us when we built the image, so all we have to do is make our database. There are a few different ways to do this, but easiest is creating a GPDB demo cluster. Since the update, the 'su gpadmin' command also runs the 'make cluster' command, in addition to a few others. After entering the below, a demo cluster will run.

~~~bash
# Prerequisites and make cluster
su gpadmin 

# Install check
make installcheck-good

# Quick test
createdb test 
psql test
~~~

Congratulations! An instance of GPDB is running inside of the Docker container. From here, the steps will cover using your Docker image and making changes to GPDB. 

### Step 5: Using Docker images and containers
Exiting your Docker container stops it, however it still exists. Periodically remove unnecessary containers and/or images so as to not waste disk space. Another thing to note is that containers maintain changes, even when exited. To maintain changes after deleting a container, first commit the changes to the Docker image. 

> [Using the Docker command line](https://docs.docker.com/engine/reference/commandline/cli/)

~~~bash
# Show running containers
docker ps

# Show all containers
docker ps -a

# Start a container and enter it
docker start [CONTAINER_ID]
docker attach [CONTAINER_ID]

# Commit changes in container to image
docker commit

# Remove container
docker rm [CONTAINER_ID]
~~~

To reuse the same image, simply enter 'docker run -it IMAGE_ID'. This does not include changes from the remote repository. There are a few different ways to include those changes, but the following is one example: 

~~~bash
cd $HOME/workspace/gpdb
git status
git checkout -b [BRANCH_NAME]
git pull --rebase origin master
eval $(docker-machine env gpdb)
docker build .
docker run -it pivotaldata/gpdb-devel
~~~

### Step 6: Compiling and making changes
The GPDB R&D team uses Docker to compile uniformly. If you want to alter the source code, the best practice is to make the changes outside of Docker, then build a brand new image. When the new image is built, the altered GPDB will be compiled, installed and ready to run. Below are example steps for this process:

~~~bash
# Clone repo
git clone git@github.com:greenplum-db/gpdb.git
git checkout -b [BRANCH_NAME]

# After a source code change
docker build .
docker run -it pivotaldata/gpdb-devel

# Committing changes to remote
git add [FILE_NAME]
git commit -m 'Message'
git push origin [BRANCH_NAME]
~~~

### Step 7: Volumes
Volumes allow you to save and persist data across containers. A volume is basically a directory outside of the default file system and exists on the host file system. They are a great way to maintain changes when working with multiple containers. A full explanation and guide can be found below:

> Guides to Volumes: [What are volumes?](http://container-solutions.com/understanding-volumes-docker/) | [Commands](https://docs.docker.com/v1.10/engine/userguide/containers/dockervolumes/)


### Conclusion
Within the GPDB R&D team, Docker is used to improve overall consistency through a uniform compilation environment. Each team member is able to develop in their own way and still end up in the same place, which is incredibly helpful in the iterative process. If inconsistent compilation environments is an issue for you, Docker is worth a try.

