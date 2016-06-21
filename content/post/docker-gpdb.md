---
authors:
- Lucas Lonergan 
categories:
- GPDB
- Docker
date: 2016-06-20T16:14:50-07:00
draft: true
short: |
    Ever wish compiling and installing GPDB was easier? This is a quick and new-user friendly guide to running Greenplum Database using Docker.
title: Running GPDB using Docker
---

n Introduction to Docker

For the inexperienced user, getting Greenplum Database to run for the first time can feel like an insurmountable task. Sneaky errors and confusing failures ambush you along your journey, inevitably leading to boiling frustration. Even for the experienced user, running GPDB can be overly complicated and time consuming. If you are a victim of needless confusion and complication, consider Docker. 

Docker is a wonderful utility that can appear to be woefully over-complicated at first. Packed with an array of steps and a steep learning curve, getting GPDB to run on Docker is a bit of a hassle. But, once you do get it running, a whole new world of simplicity and consistency opens up. The ability to synchronize your build with others, not to mention the perk of being able to use the same Docker image on multiple machines, makes life a whole lot easier in the long run. | [What is Docker?](https://www.docker.com/what-docker) | [Basic Overview](http://www.troubleshooters.com/linux/docker/docker_newbie.htm) |

| Pros         | Cons               |
|--------------|--------------------|
| Reduced risk | Initial complexity |
|  Lightweight | Extra layer        |
| Consistency  |                    |

## Getting Started
Hopefully I have convinced you to at least try running GPDB using Docker. There is some setup we have to do to get everything working, but I promise that it is (mostly) painless.
> Note: Some steps require ethernet and that you have installed "wget". These steps are for GPDB master -- steps for 4.3 Stable will be at the end.
### Step 1: Download and Install Resources
To run GPDB on Docker you will need two major tools: Docker and Virtualbox. There are great installation guides on their websites, so this step should be simple.
* **Downloads: [Docker](https://docs.docker.com/mac/) | [VirtualBox](https://www.virtualbox.org/wiki/Downloads)**
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
We now have a running virtual machine and have properly set our environment variables for Docker. We can finally begin worth directly with Docker!

### Step 3: Build and run the Docker image
We are going to build the Docker image, which is used to run a Docker container. Using the Dockerfile in Zaksoup's repo, we will construct the image, in which GPDB is already compiled. We will also install the submodules beforehand. The "docker build" step may take awhile.
> Note: In the current version, you will need to add "RUN yum -y install wget" to /docker/base/Dockerfile

 
```
# Update submodules and build image
git submodule update --init --recursive
docker build -t pivotaldata/gpdb-devel -f ./docker/base/Dockerfile

# Run the Docker image
docker images
docker run -it IMAGE_ID
```
Success! We now have a Docker image that we used to run a Docker container. You can find the IMAGE_ID by typing "docker images". After entering the run command, we will be inside of our container.

### Step 4: Starting GPDB
Finally, we are inside of our Docker container and can create our database. We do not need to compile GPDB because it was already done for us when we created the Docker image, so all we have to do is make our database. There are a few ways to do this, but we will stay basic and create a GPDB demo cluster. 
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
```
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
This part is up to personal preference and your goal. If you would like to change GPDB source code, you can either: 
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
### Conclusion
Although this may have seemed like a lot of steps, the end result is an easily reproducible, easily transferrable package for Greenplum Database that multiple teams can use to synchronize or to improve workflow. For the new use especially, tackling the GPDB installation process is a beast, so hopefully Docker helps (somewhat) simplify the process. It might not be for everyone, but it is worth giving a try and these steps should help you do just that. 
