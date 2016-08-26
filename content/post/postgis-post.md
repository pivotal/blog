---
authors:
- lucas
categories:
- PostGIS
- GPDB
date: 2016-08-26T10:47:41-07:00
draft: true
short: |
        A brief introduction to running PostGIS on GPDB.
title: Running PostGIS on GPDB
---

PostGIS is a spatial database extender for PostgreSQL, which allows for the storage and analysis of geographic objects. GIS technologies such as PostGIS are used for an array of different purposes, but they all involve increasingly detailed mapping. One example is [OpenStreetMap](https://www.openstreetmap.org/#map=4/39.81/-99.49), which maintains mapping data about roads, borders and specific destinations globally. A fairly large GIS community has gathered over the years, and their annual [FOSS4G](https://www.foss4g.org), or Free and Open Source Software for Geospatial, conventions are wildly popular. The Geospatial world is hitting a stride as newer technologies such as drones bring evolution. If any of this interests you, then you are in luck! Greenplum Database supports PostGIS and is quite simple to set up. In this post we will install PostGIS on GPDB and run some queries. | [What is PostGIS?](http://postgis.net/)

## Installing PostGIS
###Step 1: Run GPDB on docker
Before we begin, you need a running instance of GPDB. I recommend using Docker for the quickest setup, and a basic guide can be found [here](http://engineering.pivotal.io/post/docker-gpdb/). This post will assume that you are using docker to run GPDB, but the steps are generally the same even if you are not.

~~~bash
#Use docker
docker run -it your_gpdb_image
docker attach your_gpdb_container

#Most GPDB images run GPDB immediately
su - gpadmin
~~~

###Step 2: Download PostGIS and copy to docker
To install PostGIS, we need to get the PostGIS gppkg file. Go to the [Greenplum Pivotal Network](https://network.pivotal.io/products/pivotal-gpdb#/releases/2059/file_groups/250) and download the file named Greenplum Database 4.3 - PostGIS Extension for RHEL”. Next, we need to get that file into our docker container.

~~~bash
#Copy the downloaded file to your container
docker cp Downloads/postgis-ossv2.0.3_pv2.0.1_gpdb4.3orca-rhel5-x86_64.gppkg your_container:/home/gpadmin
~~~

###Step 3: Install PostGIS
We are going to use gppkg to install PostGIS, but first we need to modify permissions. Note that your file paths may be different than the ones shown. In this step, we use psql to load the base sql data necessary to use PostGIS.

~~~bash
#Change permissinos
chown -R home/gpadmin gpadmin

#Install PostGIS
su - gpadmin
gppkg -i postgis-ossv2.0.3_pv2.0.1_gpdb4.3orca-rhel5-x86_64.gppkg
cd /usr/local/greenplum-db-4.3.7.1/share/postgresql/contrib/postgis-2.0
psql -d gpadmin -f /usr/local/greenplum-db-4.3.7.1/share/postgresql/contrib/postgis-2.0/postgis.sql
psql -d gpadmin -f /usr/local/greenplum-db-4.3.7.1/share/postgresql/contrib/postgis-2.0/spatial_ref_sys.sql
~~~

###Step 4: Get your data
Now that PostGIS is installed, we need some data. Go [here](http://workshops.boundlessgeo.com/postgis-intro/) and click on the data bundle link, then copy the bundle into your docker container. After that, shp2pgsql allows us to deliver our data to the database.

~~~bash
#Copy the bundle
docker cp Downloads/postgis-workshop sick_varahamihira:/home/gpadmin

#Use shp2pgsql to deliver data
cd /home/gpadmin/postgis-workshop
shp2pgsql -s 26918 -D nyc_subway_stations.shp | psql -d gpadmin -U gpadmin
shp2pgsql -s 26918 -D nyc_streets.shp | psql -d gpadmin -U gpadmin
shp2pgsql -s 26918 -D nyc_neighborhoods.shp | psql -d gpadmin -U gpadmin
shp2pgsql -s 26918 -D nyc_homicides.shp | psql -d gpadmin -U gpadmin
shp2pgsql -s 26918 -D nyc_census_blocks.shp | psql -d gpadmin -U gpadmin

#Test the data
psql
\dt
select * from geometry_columns;
select boroname from nyc_neighborhoods;
~~~

###Step 5: Query the data
Congratulations - you now having PostGIS installed on GPDB and populated with data! Now we can run queries using SQL.

~~~bash
#Warm-up query
select sum(popn_total) as population from nyc_census_blocks where boroname = 'Manhattan';
select type, sum(st_length(geom)) as length from nyc_streets group by type order by length desc;
~~~

For detailed examples and exercises, [Boundless](http://workshops.boundlessgeo.com/postgis-intro/spatial_relationships.html) offers great tutorials.
