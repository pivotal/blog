---
authors:
- llonergan 
categories:
- GPDB
- Docker
date: 2016-06-20T16:14:50-07:00
draft: true
short: |
	An introduction to the GPDB R&D team's process using Docker.
title: Running GPDB using Docker
---

## Why Docker?
Compiling in different environments is an incredibly frustrating hurdle in the development process. To combat this, the GPDB R&D team has been using Docker to improve workflow speed and consistency. While a little complicated at first, Docker pushes for a standard compilation environment for GPDB users, sidestepping the compilation confusions that often pop up. Through Docker, the GPDB R&D team synchronizes after the development stage and easily compares results in the Docker-run environment. Testing is also expedited due to the consistent nature of Docker. | [What is Docker?](https://www.docker.com/what-docker) | [Basic Overview](http://www.troubleshooters.com/linux/docker/docker_newbie.htm) |

## Getting Started with Docker
There are a few pieces to the Docker puzzle, namely the Dockerfile and the container. The Dockerfile is used to build an image, which is then used to run the container. The Dockerfile is currently located in Zaksoup’s branch of GPDB master, so we will need to grab that as well as Docker itself. 

### Step 1: Gather Resources
To run GPDB on Docker you will need two major tools: Docker and Virtualbox. There are great installation guides on their websites.
* Downloads: [Docker](https://docs.docker.com/mac/) |
[VirtualBox](https://www.virtualbox.org/wiki/Downloads)

##### Copy GPDB repositories from Github
We will be using two Github repositories: [Master](https://github.com/greenplum-db/gpdb) | [Zaksoup](https://github.com/zaksoup/gpdb) . Zaksoup's branch contains the very necessary Dockerfile, which we will use to create our Docker image. The following commands will clone GPDB master and add Zaksoup's branch. 
```
# Clone and add
git clone git@github.com:greenplum-db/gpdb.git
git remote add zaksoup git@github.com:zaksoup/gpdb.git

# Update
git fetch --all
git checkout zaksoup/master
git rebase origin/master
```

### Step 2: Create your virtual environment
In order to create a Docker container, inside of which we will run an instance of the database, we must first create a virtual space where our container will exist. We will do so through VirtualBox. In this step, make sure not to over-allocate resources.
```
# Create virtual machine
docker-machine create -d virtualbox --virtualbox-cpu-count 2 --virtualbox-disk-size 50000 --virtualbox-memory 4096 gpdb

# Set environment variables for Docker
eval $(docker-machine env gpdb)
```
We now have a running virtual machine and have properly set our environment variables for Docker.

### Step 3: Build and run the Docker image
Using the Dockerfile in Zaksoup's repo, we will construct the image. Note that when we build the image, GPDB will compile and install. We will also install several submodules beforehand. The "docker build" step may take awhile.
* Note: In the current version, you will need to add "RUN yum -y install wget" to /docker/base/Dockerfile. Also, you may need to be connected to ethernet.

```
# Update submodules and build image
git submodule update --init --recursive
docker build -t pivotaldata/gpdb-devel -f ./docker/base/Dockerfile
# Run the Docker image
docker images
docker run -it IMAGE_ID
```

We now have a Docker image, which will be used to run the Docker container. After entering the run command, we will be inside our container.

### Step 4: Starting GPDB
Finally, we get to the database. We do not need to compile GPDB because it was already done for us when we created the Docker image, so all we have to do is make our database. There are a few ways to do this, but we will stay basic and create a GPDB demo cluster. 

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

Congratulations! We officially have a working instance of GPDB running inside Docker. The next steps will cover how to reuse your Docker image and how to make changes to GPDB in Docker.

### Step 5: Using Docker images and containers
If you exit your Docker container, you can using these commands to use it again.

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

* Even if a container is not running, it still exists. Make sure to periodically remove any unnecessary containers and/or images. Also, your container maintains changes even if you exit it. However, if you want changes to persist after you remove the container, you need to commit your changes to the Docker image. 

If we want to create a new container from a Docker image, we can use “docker run -it ID”. However, if we want a new, separate image we use “docker build .”. If we want to use changes from the remote repository, the following will update your local repo and build a new image: 

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
If you want to compile and install GPDB within the container, the following will do so:

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

Building and running a new image is more common because you are able to include any changes to the repository. You can do so by repeating code from Step 5. 

### Conclusion
Within the GPDB R&D team, Docker is used to improve overall consistency through a uniform compilation environment. Each team member is able to develop in their own way and still end up in the same place, which is incredibly helpful in the iterative process. The long-winded installation process aside, if compilation environments is an issue for you, Docker is worth a look.

