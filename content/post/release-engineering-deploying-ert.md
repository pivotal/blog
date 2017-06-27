---
authors:
- kkelani
categories:
- Infrastructure
- Elastic Runtime Tile
- Release Engineering
- Terraform
- Ops Manager
- om
date: 2017-06-27T22:00:00-07:00
short: |
  A look at how Release Engineering deploys and tests the Elastic Runtime Tile
title: "Using Terraform, Concourse, and om to Continuously Deploy Pivotal Cloud
Foundry's Elastic Runtime"
---
At Pivotal, we strive for empathy with our customers. One way we achieve this: running and managing our own products, just as a customer would. Here’s a look at how our Release Engineering team maintains the [Elastic Runtime Tile (ERT)](https://network.pivotal.io/products/elastic-runtime). The ERT includes both open-source and proprietary components that power [Pivotal Cloud Foundry](https://pivotal.io/platform). [Ops Manager](https://docs.pivotal.io/pivotalcf/1-11/customizing/) is a web application that platform operators use to configure and deploy tiles, such as the ERT, [MySQL](https://network.pivotal.io/products/pivotal-mysql), [Redis](https://network.pivotal.io/products/p-redis), [RabbitMQ](https://network.pivotal.io/products/pivotal-rabbitmq-service), etc.

{{< responsive-figure src="/images/release-engineering-deploying-ert/opsman-initial.png" class="center small" caption="Ops Manager Web App" >}}

Our team works in the space between platform component teams and customers. Our core responsibilities are to consume platform components, expose configuration options to operators in a user-friendly manner via forms on Ops Manager, and test the platform. Furthermore, the team applies bug fixes and critical vulnerability patches to previous versions of the ERT.

{{< responsive-figure src="/images/release-engineering-deploying-ert/components.png" class="center small" caption="OSS and proprietary components flow into the ERT" >}}

It is critical that we deploy and test the product in production-like situations on the infrastructures our customers use. After all, customers depend on us for long-term support. Our testing matrix below details the versions, upgrade paths, and infrastructures we test.

{{< responsive-figure src="/images/release-engineering-deploying-ert/testing-matrix.png" class="center small" caption="ERT Testing Matrix (N, M are latest versions)" >}}

This post explains the [Concourse](https://www.concourse.ci)-driven system we use to deploy and test the ERT. We use [terraform](https://www/terraform.io) to create infrastructure and an Ops Manager instance. We built a tool called `om` that interacts with Ops Manager to configure and deploy the ERT. To see the pipelines in action go to [https://releng.ci.cf-app.com](https://releng.ci.cf-app.com).

{{< figure src="/images/release-engineering-deploying-ert/pipeline.png" class="center" caption="Pipeline deploying ERT 1.11 on GCP">}}

## <a name="creating-infrastructure" href="#creating-infrastructure">Creating Infrastructure</a>
[Terraform](https://www.terraform.io)  automates the creation and modification of infrastructure. It supports all major cloud providers. Users define their infrastructure components (load balancer, DNS, network configuration, etc.) in template `.tf` files. After running `terraform apply`, the user is given a `.tfstate` state file that contains information about the infrastructure. This is an important file - it allows you to manipulate and destroy your infrastructure in a painless, reentrant way. As long as you have the state file, terraform can do its job.

{{< figure src="/images/release-engineering-deploying-ert/terraform.png" class="center" caption="terraform creates resources in Google Cloud">}}

Our team maintains a series of repos with terraform templates for [Google Cloud](https://github.com/pivotal-cf/terraforming-gcp), [AWS](https://github.com/pivotal-cf/terraforming-aws), and [Azure](https://github.com/pivotal-cf/terraforming-azure). We use these templates to stand up infrastructure on each cloud. Since templates do not contain credentials, we share them freely. Describing infrastructure with sharable template files (instead of documentation or writing a client program) is one of the major benefits of terraform.

To create the infrastructure, our pipeline pulls templates from one of the aforementioned repos. A terraform variables file `.tfvars` with environment specific values (credentials, SSL certs, etc.) is created and then `terraform apply` is executed. The [terraform concourse resource](https://github.com/ljfranklin/terraform-resource) is an easy, safe way to run terraform templates. As mentioned earlier, the state file is important and confidential. The resource takes templates and variables as inputs, performs the `terraform apply` command, and outputs your state file to an Amazon S3 bucket of your choice. This puts the state file in a safe, secure location for further operations.

Check out the `README.md` in the terraforming repo of your choice for specific info on how to get started.

## <a name="configuring-opsman" href="#configuring-opsman">Configuring Ops Manager</a>
After the infrastructure is stood up, it’s time to configure authentication so we can interact with Ops Manager. We automate with Concourse, so we use the aforementioned `om` program for this purpose.

Some of you may be familiar with `opsmgr` - a similar tool that used Capybara to automate form submission. Unfortunately, opsmgr was susceptible to a high rate of false negatives, like failing to find elements on a page because they were overlapping. As a result, we created om to improve the reliability and speed of our pipelines.

{{< figure src="/images/release-engineering-deploying-ert/opsman-configure-authentication.png" class="center" caption="Configuring Ops Manager authentication" >}}

To start interacting with [Ops Manager via the API](https://opsman-dev-api-docs.cfapps.io/), we set up authentication using the following command:

~~~bash
$ om --target https://pcf.example.com configure-authentication \
  --user desired-username --password desired-password \
  --decryption-passphrase desired-passphrase
~~~

## <a name="uploading-artifacts" href="#uploading-artifacts">Uploading Artifacts</a>
Next, the pipeline uploads the ERT and its stemcell to Ops Manager. The ERT contains compiled releases of open-source Cloud Foundry components like [loggregator](https://www.github.com/cloudfoundry/loggregator), [UAA](https://www.github.com/cloudfoundry/uaa-release), and [Diego](https://www.github.com/cloudfoundry/diego-release), as well as Pivotal Cloud Foundry components like [App Autoscaler](https://docs.pivotal.io/pivotalcf/1-10/appsman-services/autoscaler/using-autoscaler.html) and [Apps Manager](https://docs.pivotal.io/pivotalcf/1-11/console/index.html). The tile also contains metadata that describes its properties, and a manifest template that is populated with user-provided configuration (see [Configuring ERT](#configuring-ert)).

{{< figure src="/images/release-engineering-deploying-ert/opsman-upload.png" class="center" caption="Uploading stemcell for ERT" >}}

Since our focus is automation, we use `om` for the upload. The ERT bits are on [Pivotal Network](https://network.pivotal.io), a site that contains many Pivotal products like [Redis](https://network.pivotal.io/products/p-redis), [Spring Cloud Services](https://network.pivotal.io/products/p-spring-cloud-services), and [Pivotal Cloud Foundry Runtime for Windows](https://network.pivotal.io/products/runtime-for-windows).

Stemcells can be found on [bosh.io](https://www.bosh.io). The required stemcell version for an ERT is found on the tile’s download page. For automation purposes, our pipeline unzips the tile, finds the metadata file, and extracts the required stemcell version from the `stemcell_criteria` section of the metadata.

Once we have the ERT and stemcell, they are uploaded to Ops Manager via the following `om` commands:

~~~bash
$ om --target https://pcf.example.com --user some-user --password password upload-product \
  --product /path/to/product/file.pivotal

$ om --target https://pcf.example.com --user some-user --password password stage-product \
  --product-name cf --product-version 1.11.1

$ om --target https://pcf.example.com --user some-user --password password upload-stemcell \
  --stemcell /path/to/stemcell/file.tgz
~~~

## <a name="configuring-bosh" href="#configuring-bosh">Configuring BOSH</a>
Cloud Foundry uses BOSH for deployment; so does Ops Manager in Pivotal’s commercial distribution. Much of the same configuration that is required when using [bosh-init](https://bosh.io/docs/using-bosh-init.html) or [bbl](https://github.com/cloudfoundry/bosh-bootloader) is applicable to configuring BOSH via Ops Manager.

{{< figure src="/images/release-engineering-deploying-ert/opsman-configure-bosh.png" class="center" caption="Configuring BOSH director" >}}

To configure the BOSH Director, you need to provide Ops Manager with details about the infrastructure the platform will be deployed into (see [Creating infrastructure](#creating-infrastructure)). Terraform to the rescue! Our pipeline extracts this information from the terraform state file `.tfstate` via the following command:

~~~bash
$ terraform output -state terraform.tfstate | jq -r ‘map_values(.value)’
{ 
    "vm_tag": "some-id-tag-for-vms",
    "project": "some-gcp-project",
    "network_name": "some-network",
    "azs": ["us-central1-a", "us-central1-b", "us-central1-c"],
    ...
}
~~~

These values are provided to the configure-bosh command. Here is an example that sets the IaaS and network configuration for the Director.

~~~bash
$ om --target https://pcf.example.com --username some-user --password some-password configure-bosh \
  --iaas-configuration '{"default_deployment_tag": "some-id-tag-for-vms", "project": "some-gcp-project"}'

$ om --target https://pcf.example.com --username some-user --password some-password configure-bosh \
  --az-configuration '{"availability_zones": [{"name": "us-central1-a"}, {"name": "us-central1-b"}, {"name": "us-central1-c"}]}'
...
~~~

To fully configure the BOSH Director, check out the examples in `configure-bosh` [command documentation](https://github.com/pivotal-cf/om/tree/master/docs/configure-bosh).

## <a name="configuring-ert" href="#configuring-ert">Configuring ERT</a>

Configuration for open-source Cloud Foundry is provided via a manifest file. However, configuration of the ERT is exposed by a series of forms on Ops Manager and these values are populated into the manifest. The forms allow operators to enable features like container networking, TCP routing, and specify values like SSL certificates for the routers, a destination for external system logging, desired location for the Cloud Controller database, etc. Values that are provided in these forms are translated into properties for their respective BOSH jobs.

{{< figure src="/images/release-engineering-deploying-ert/opsman-configure-ert.png" class="center" caption="Configuring ERT" >}}

Here's an example of part of an `om configure-product` command that is used to configure the [`system_domain`](https://github.com/cloudfoundry/cloud_controller_ng/blob/c11841b5675aaa47ccd2a70b742eb25601d26d2c/bosh/jobs/cloud_controller_ng/spec#L74-L75) value that would be provided to the `cloud_controller` job:

~~~bash
$ om --target https://pcf.example.com --username some-user --password some-password configure-product \
  --product_properties='{".cloud_controller.system_domain": {"value": "sys.example.com"}, ... }'

...
~~~

To fully configure the ERT, check out the examples in the `configure-product` [command documentation](https://github.com/pivotal-cf/om/tree/master/docs/configure-product).

Note: Ops Manager has a useful API method that [displays all configurable
properties of a
tile](https://opsman-dev-api-docs.cfapps.io/#viewing-product-properties). This
can be useful when crafting an `om` command to configure a property not covered
in the `om` examples and documentation.

## <a name="deploying-ert" href="#deploying-ert">Deploying ERT</a>
Now that BOSH is ready to deploy VMs and the ERT is configured, the final step is to deploy the platform!

Ops Manager uses `bosh-init` to deploy the Director with the configuration provided to the `om configure-bosh` command in the <a href="#configuring-bosh">Configuring BOSH</a> section. It issues a `bosh deploy` to deploy a manifest with the configuration provided to the `om configure-product` command in <a href="#configuring-ert">Configuring the ERT</a> section. The lengthy compilation step is skipped; components in the ERT have already been compiled.

The pipeline applies changes by issuing the following command:

~~~bash
$ om --target https://pcf.example.com --user some-user --password some-password apply-changes
~~~

Running the `apply-changes` command will tail the Ops Manager installation output and exit `0` for a successful deployment and `1` for a failed deployment. The command is also reentrant meaning it will re-attach to an installation in progress.

## <a name="conclusion" href="#conclusion">Conclusion</a>
Automation is critical to testing the Elastic Runtime Tile. To ensure we release the highest quality software, it is imperative that we deploy and test different versions, upgrade paths, and configurations on numerous IaaSes. Tools like terraform make creating and managing infrastructure state simple. We created om to automate a stable, reentrant interaction with Ops Manager. Tooling is at the heart of Release Engineering. It has allowed us to maintain long-term support for the products we ship to customers.
