---
authors:
- lucas
categories:
- GPDB
- Docker
date: 2016-06-22T13:24:13-07:00
draft: true
short: |
 A look into how the GPDB R&D team uses Docker to increase consistency. 
title: Running GPDB using Docker
---

Compiling in different environments is an incredibly frustrating hurdle in the development process. To combat this, the GPDB R&D team uses Docker to improve workflow speed and consistency. While a little complicated at first, Docker pushes for a standard compilation environment for GPDB users, sidestepping the compilation confusions that often pop up. Through Docker, the GPDB R&D team synchronizes after the development stage and easily compares results in the Docker-run environment. Testing is also expedited due to the consistent and streamlined nature of Docker. | [What is Docker?](https://www.docker.com/what-docker) | [Basic Overview](http://www.troubleshooters.com/linux/docker/docker_newbie.htm) | 

## Getting Started with Docker
Docker is composed of three core elements: dockerfiles, images, and containers. A dockerfile provides command-line instructions which are used to build an image. An image is a collection of root filesystem changes and the corresponding execution parameters for use in runtime [1](https://docs.docker.com/engine/reference/glossary/#image), and is read-only. Finally, a container is a stateful instance of an image [2](https://docs.docker.com/engine/reference/glossary/#container). GPDB runs inside the container, but is compiled when the image is constructed. Since the dockerfile, the initial piece of the puzzle, is currently only located in Zaksoup's branch of GPDB master, we will need to grab that Github repo in addition to master. 

### Step 1: Gather Resources
Two important tools are needed to run GPDB on Docker: Docker and VirtualBox. VirtualBox manages virtual machines, which is where we will run our instance of GPDB. Detailed installation guides are on their websites. 

> Downloads: [Docker](https://docs.docker.com/mac/) | [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

We need two Github repositories: [Master](https://github.com/greenplum-db/gpdb) | [Zaksoup](https://github.com/zaksoup/gpdb) . Zaksoup's branch contains the necessary dockerfile to create the image. The following commands clone GPDB master and add Zaksoup's branch.

```
# Clone and add
git clone git@github.com:greenplum-db/gpdb.git
git remote add zaksoup git@github.com:zaksoup/gpdb.git

# Update
git fetch --all
git checkout zaksoup/master
git pull -rebase origin/master
```

### Step 2: Create your virtual environment
In order to create a Docker container, inside of which we will run an instance of the database, we need to create a virtual space where our container will exist. We will do so through VirtualBox. In this step, make sure not to over-allocate resources.

```
# Create virtual machine
docker-machine create -d virtualbox --virtualbox-cpu-count 2 --virtualbox-disk-size 50000 --virtualbox-memory 4096 gpdb

# Set environment variables for Docker
eval $(docker-machine env gpdb)
```

### Step 3: Build and run the Docker image
We will use the dockerfile to build an image. Note that when we build, GPDB will compile and install. Beforehand, we need to update submodules. This step uses the GPDB Dockerhub repository, found [here](https://hub.docker.com/r/pivotaldata/gpdb-devel/). After entering the run command, we will be immediately inside the container. 

> In the current version, you will need to add "RUN yum -y install wget" to /docker/base/dockerfile. Also, you may need to be connected to ethernet.

```
# Update submodules
git submodule update --init --recursive

# Build Docker image
docker build -t pivotaldata/gpdb-devel -f ./docker/base/Dockerfile

# Run Docker image
docker images
docker run -it IMAGE_ID
```

### Step 4: Starting GPDB
Now that we are inside of the container, we are able to work with the database itself. We do not need to compile GPDB because it was already done for us when we built the image, sll we have to do is make our database. There are a few different ways to do this, but easiest is creating a GPDB demo cluster. Some steps are important before 'make cluster', especially logging in as a user other than root, in this case as gpadmin.

```
# Prerequisites
./docker/start_ssh.bash
su - gpadmin 
source /usr/local/gpdb/greenplum_path.sh

# Make demo cluster
cd /workspace/gpdb/gpAux/gpdemo
make cluster 
export MASTER_DATA_DIRECTORY=/workspace/gpdb/gpAux/gpdemo/datadirs/qddir/demoDataDir-1
export PGPORT=15432
export PGDATABASE=template1

# Quick test
createdb test 
psql test
```

Congratulations! An instance of GPDB is running inside of the Docker container. From here, the steps will discuss using your Docker image and making changes to GPDB. 

### Step 5: Using Docker images and containers
Exiting your Docker container stops it, however it still exists. Periodically remove unnecessary containers and/or images so as to not waste disk space. Another thing to note is that containers maintain changes, even when exited. To maintain changes after deleting a container, first commit the changes to the Docker image. 

> [Using the Docker command line](https://docs.docker.com/engine/reference/commandline/cli/)

```
# Show running containers
docker ps

# Show all containers
docker ps -a

# Start a container and enter it
docker start ID
docker attach ID

# Commit changes in container to image
docker commit

# Remove container
docker rm CONTAINER_ID
```

To reuse the same image, simply enter 'docker run -it IMAGE_ID'. This does not include changes from the remote repository. There are a few ways to do so, but the following is one example: 

```
cd $HOME/workspace/gpdb
git status
git checkout zaksoup/master
git rebase origin/master
eval $(docker-machine env gpdb)
docker build .
docker run -it IMAGE_ID
```

### Step 6: Compiling and making changes
The GPDB R&D team uses Docker to compile uniformly, but there are a couple of ways to do so: 
1. Change the source code inside the container, then compile and install
2. Make a change to the local repo, then build a new image and run it

In most cases, it is common to make changes locally, then build a new image and run it. On the other hand, if you want to compile and install GPDB within the container, the following will do so:

```
# Compile and install
docker run -it IMAGE_ID
./docker/start_ssh.bash
su - gpadmin
cd /workspace/gpdb/
make clean
./configure
make
make install
```

### Conclusion
Within the GPDB R&D team, Docker is used to improve overall consistency through a uniform compilation environment. Each team member is able to develop in their own way and still end up in the same place, which is incredibly helpful in the iterative process. The long-winded installation process aside, if inconsistent compilation environments is an issue, Docker is worth a try.

