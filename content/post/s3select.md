---
authors:
- xiwei
categories:
- Greenplum
- PXF
- S3
- S3 Select
- AWS 
date: 2019-07-17T09:00:00Z
draft: true
short: |
  

title: Utilizing S3 Select for Efficient S3 Object Retrieval via PXF
image: /images/pairing.jpg
---

## Overview

This new feature of PXF enables our users to make more efficient queries against S3 object stores by allowing them to utilize S3 Select. With PXF's implementation on S3 Select support, query predicate and column projection pushdown to S3 is now available. This helps users to retrieve only a subset of data from an object with simple SQL expressions, reducing costs and increasing efficiency.


With support of S3 Select by PXF, users can retreive partial data more efficiently from their S3 object storages with simple SQL expressions. After setting up S3 object stores, users can [configure PXF](https://gpdb.docs.pivotal.io/6-0Beta/pxf/objstore_cfg.html) and have the option to enable S3 Select when querying to their S3 data sources. The SQL query strings they entered through Greenplum will be processed by PXF to determine whether the query can be optimized by S3 Select.

{{< responsive-figure src="/images/s3select.png" class="center" >}}

### Keep it technical.

People want to to be educated and enlightened.  Our audience are engineers, so the way to reach them is through code.  The more code samples, the better.

Pivotal-ui comes with a bunch of nice helpers.  Make use of them.  Check out the example styles below:

---



{{< responsive-figure src="/images/pairing.jpg" class="left" >}}


~~~python
def function_name(lst, str){
  print(str)
}
~~~

| Header 1        | Header 2  | ...        |
| --------------  | :-------: | ---------: |
| SSH (22)        | TCP (6)   | 22         |
| HTTP (80)       | TCP (6)   | 80         |
| HTTPS (443)     | TCP (6)   | 443        |
| Custom TCP Rule | TCP (6)   | 2222       |
| Custom TCP Rule | TCP (6)   | 6868       |



### References:
https://aws.amazon.com/about-aws/whats-new/2018/04/amazon-s3-select-is-now-generally-available/

https://aws.amazon.com/blogs/aws/s3-glacier-select/
