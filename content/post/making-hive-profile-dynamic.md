---
authors:
- Add another author here
- alex
categories:
- HAWQ
- PXF
- Hive
- Unmanaged data
date: 2017-01-31T14:52:56-08:00
draft: true
short: |
  Post about efficient usage of all existing PXF Hive-related profiles with minimal user interfaction
title: Making Hive profile dynamic
---
# Introduction
## Two ways of accesing unmanaged data using PXF
### Generally speaking there are two ways of accessing Hive tables using PXF:
 * Create HAWQ external table using "pxf" protocol and certain profile(or fragmenter, accessor, resolver) 
  * User has to know underlying Hive table's metadata
  * In case when table is heterogeneous(has multiple partitions with different storage formats) user has to use ultimate and generic "Hive" profile, which obviously not optimized for particular storage format
 * Use HCatalog integration
  * Information about underlying storage formats is ignored and "Hive" profile used

### More efficient profiles
#### Apart from very generic "Hive" profile, PXF has other Hive-related profiles, optimized for popular storage formats:
* HiveRC. Supports Hive tables stored in RCFile format(Record Columnar File).
* HiveText. It's perfect for Hive tables stored in Text format. Worth of mentioning that it bypasses records as they are stored in disk to HAWQ side, and resolution text to actual record happens on HAWQ.
* HiveORC. Profile which was built recently to support Hive tables stored in ORC.

# Problem
1. As for now there is only one way to read heterogeneous Hive tables - using inefficient "Hive" profile.
2. It's unable to query Hive tables directly(without creation of extarnal HAWQ table) and use efficient profile(i.e. HiveORC).

# Solution
Therefore it was obvoius to come up with solution, which could leverage existing heritage, be more fine-grained when reading data. Following Apache issues cover scope - https://issues.apache.org/jira/browse/HAWQ-1177, https://issues.apache.org/jira/browse/HAWQ-1228 of PXF using optimal profile based on table's format(s). 
### Briefly describing changes were made:
* All text Hive profiles(HiveText, HiveRC) now could supply data to HAWQ in two formats: TEXT and GPDBWritable.
* Metadata PXF API now has additional format-related information(i.e. delimiter etc) needed for deserialization.
* Fragmenter PXF API returns profile, which is optimal for this particular fragment(equivalent to HDFS datablock).
* Instead of using static single profile value for all fragments, HAWQ PXF-bridge component uses profile, which comes along with fragment meta information.

### Before vs after:
#### Let's say we have Hive table, partitioned by string column, having four partitions stored as TEXTFILE, SEQUENCEFILE, RCFILE, ORCFILE:
```
hive> desc reg_heterogen;
OK
t0                  	string              	                    
t1                  	string              	                    
num1                	int                 	                    
d1                  	double              	                    
fmt                 	string              	                    
	 	 
# Partition Information	 	 
# col_name            	data_type           	comment             
	 	 
fmt                 	string              	                    
Time taken: 0.06 seconds, Fetched: 10 row(s)
hive> show partitions reg_heterogen;
OK
fmt=orc
fmt=rc
fmt=seq
fmt=txt
Time taken: 0.117 seconds, Fetched: 4 row(s) 
```

As it was mentioned before, there are two ways accessing data, we can start from more convenient for user.
Thus we just have to know table name:
```
pxfautomation=# SELECT * FROM hcatalog.default.reg_heterogen;
  t0   |  t1  | num1 | d1 | fmt 
-------+------+------+----+-----
 row1  | s_6  |    1 |  6 | orc
 row2  | s_7  |    2 |  7 | orc
 row3  | s_8  |    3 |  8 | orc
 row4  | s_9  |    4 |  9 | orc
...
 row8  | s_13 |    8 | 13 | txt
 row9  | s_14 |    9 | 14 | txt
 row10 | s_15 |   10 | 15 | txt
(40 rows)
```

What happens under the hood:
{{< responsive-figure src="/images/making-hive-profile-dynamic/HAWQ-to-PXF-http.png" alt="HTTP comminication between HAWQ and PXF" >}}
As we can see, when user issues HCatalog query, one Metadata, two Fragments and four Bridge calls(one Bridge call per each fragment) being sent from HAWQ to PXF.


|Before change |After change |
|-------|------|
|**Metadata API**|
|`{"PXFMetadata":[`|`{"PXFMetadata":[`|
|`{"item":{"path":"default",`|`{"item":{"path":"default",`|
|`"name":"reg_heterogen_three_partitions"},`|`"name":"reg_heterogen_three_partitions"},`|
|`"fields":[{"name":"t0","type":"text",`|`"fields":[{"name":"t0","type":"text",`|
|`"sourceType":"string"},`|`"sourceType":"string","complexType":false},`|
|`...`|`...`|
|`{"name":"fmt","type":"text",`|`{"name":"fmt","type":"text",`|
|`"sourceType":"string"}],`|`"sourceType":"string","complexType":false}],`|
|`}]}`|`"outputFormats":["TEXT","GPDBWritable"],`|
||`"outputParameters":{"DELIMITER":"1"}}]}`|
|**Fragmenter API**|
|`{"PXFFragments":[`|`{"PXFFragments":[`|
|`{"sourceName":"/hive/whs/hive_orc/000000_0",`|`{"sourceName":"/hive/whs/hive_orc/000000_0",`|
|`"index":0,"replicas":["host1","host2"],`|`"index":0,"replicas":["host1","host2"],`|
|`"metadata":"...","userData":"..."},`|`"metadata":"...","userData":"...",`|
||`"profile":"HiveORC"},`|
|`...`|`...`|
|`{"sourceName":"/hive/whs/hive_rc/000000_0",`|`{"sourceName":"/hive/whs/hive_rc/000000_0",`|
|`"index":n,"replicas":["host2","host3"],`|`"index":n,"replicas":["host2","host3"],`|
|`"metadata":"...","userData":"..."},...]}`|`"metadata":"...","userData":"...",`|
||`"profile":"HiveRC"},...]}`|


The comparison above shows, that after change we are able to treat data more fine-grained, use separate profile for each fragment if needed in oppose to treating a whole table with one profile before.
# Future directions
* Optimize usage of profile for all HDFS profiles. As far as PXF has different optimized profiles for accessing files on HDFS(HdfsTextSimple, HdfsTextMulti, Avro etc), it also makes sense to do a similar improvement for HDFS.
* Potentially profile parameter might be decommissioned or just require some generic value, like "Hive", "HDFS", and PXF would figure out internally which optimized one to use. And users don't have to worry about details.
* Expose more information about Hive table in \d+ psql command, because there more attributes available in a Metadata API response.
