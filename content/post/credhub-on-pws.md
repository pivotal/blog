---
authors:
- dreeve
categories:
- CredHub
- Operations
date: 2017-09-04T14:57:22Z
draft: true
short: 
title: Transitioning From Using Locally-Stored Secrets To Using CredHub For Pivotal Web Services
image: /images/pairing.jpg
---

# CredHub On PWS

[Credhub](https://github.com/cloudfoundry-incubator/credhub<Paste>) is designed to manage passwords, secrets, certificates, and other secret information for a Cloud Foundry environment. The Pivotal CloudOps team uses a CredHub instance co-located with a BOSH Director to manage the secrets required to continuously deploy Pivotal Web Services with minimal downtime. This article will discuss how the team moved from storing secret information in flat files to storing secrets -- and automatically generating SSL certificates! -- using BOSH variable generation and CredHub.


## Before CredHub

Before using CredHub with BOSH variables, the CloudOps team used a tool named [secrets-sanitizer](https://github.com/pivotal-cloudops/secrets-sanitizer) to remove (or “sanitize”) secret values from manifests so that we could store them in a separate repository. Given that the team was working with manifests that already contained secrets, the `secrets-sanitizer` tool had the side-effect of being a useful abstraction on our path to importing all of our secret credentials to CredHub.


## A Brief Introduction to `secrets-sanitizer`

`secrets-sanitizer` is a CloudOps-developed tool that can be used to remove secrets from manifest files. `secrets-sanitizer` edits the given manifest, replacing values that it deems “secret” with a reference to a value that is stored elsewhere. Given the following snippet from a manifest:

```
properties:
	acceptance_tests:
		api: api.example.com
		apps_domain: example.com
		admin_user: watermelon
		admin_password: apology_cake
```

Running `secrets-sanitizer` on this file might look like this:

```
sanitize -i mani.yml -s ~/production_secrets/
```

The resulting manifest has the secret value replaced by a key wrapped in double curly braces (`{{}}`):

```yaml
properties:
  acceptance_tests:
    api: api.example.com
    apps_domain: example.com
    admin_user: watermelon
    admin_password: "{{properties_acceptance_tests_admin_password}}"
```

`secrets-sanitizer` removed the secret value and stored it in the file secrets-mani.json in the location specified by the `-s` argument. “De-sanitizing” the same manifest with the same arguments (by running `desanitize -i mani.yml -s ~/my_secrets/`) would re-insert `EH7kee4eenei0Oh` for the value of `admin_password`.

## Installing CredHub

Credhub is deployed as a co-located BOSH release. Further instructions for deployment can be found in the [`credhub-release` documentation](https://github.com/pivotal-cf/credhub-release#deploying-credhub).

## Converting A Deployment To Use CredHub

Given that the manifests we use to deploy PWS had been run through the `secrets-sanitizer` tool, they had values surrounded by double curly braces. To fully utilize CredHub, CloudOps was interested in using BOSH variable interpolation to automatically replace the appropriate tags in each deployment manifest. 

Converting one of PWS’ manifests to use CredHub was a straightforward process:
- Import credentials into CredHub
- Convert manifest from `secrets-sanitizer` format to a BOSH interpolation-friendly format
- Configure BOSH to use CredHub as a config server

### Importing Credentials Into CredHub

As mentioned previously, the `secrets-sanitizer` tool creates a JSON file to store credentials. From a machine that could connect to the co-located CredHub instance, we ran a handful of lines of ruby that read each credential from the appropriate JSON credentials file and set that value in CredHub. 


```ruby
#!/usr/bin/env ruby

require 'json'

input = ARGV ? $< : File.new(ARGV[0])

credentials = JSON.parse(input.read)

credentials.each do |key, value|
  output = "credhub set --name /secrets-sanitizer/#{key} --value #{value} --type value"
  puts output
end
```

A few notes. This script reads from `STDIN` and prints the `credhub` CLI command to `STDOUT`.

The `--name` we give each value in CredHub is prepended with `/secrets-sanitizer`. CredHub supports namespacing data by paths, so we used `/secrets-sanitizer` as a way of identifying credentials that were loaded using our `secrets-sanitizer` tool.

CredHub has a handful of [credential types](https://docs.cloudfoundry.org/credhub/credential-types.html), including the generic `value`, as well as more specific types such as `password` and `certificate`. Our initial load imported all credentials as type `value`s. Since the majority of our credentials were named things like `cert` or `password`, a few modifications of the script allowed us to easily create new credentials with the appropriate types.

After loading these values into CredHub, we needed to convert the manifest from the `secrets-sanitizer` format to a BOSH interpolation-friendly format.


### Converting The Manifest From Secrets-Sanitizer to BOSH Interpolation

We didn't spend very much effort on this. This is about all we needed to convert the braces and prepend `/secrets-sanitizer/` to the BOSH interpolation references.

```
sed 's/{{/((\/secrets-sanitizer\//g' mani.yml | sed 's/}}/))/g'
```


### Configure BOSH to Use CredHub as a Config Server

We configured CredHub as a BOSH Config Server using UAA and pointing to the appropriate endpoints:

```
config_server:
  enabled: true
  url: https://bosh.run.pivotal.io:8844/api/
  ca_cert: "((director_config_server_ca_cert))"
  uaa:
    url: https://bosh.run.pivotal.io:8443
    client_id: credhub_director
    client_secret: "((director_config_server_uaa_client_secret))"
    ca_cert: "((director_config_server_uaa_ca_cert))"

```

## We Re-Deployed, And It Worked!

...After a few `bosh deploy --dry-run`s to check the output. We've been using CredHub as a BOSH Config Server to deploy PWS on a frequent basis ever since.

## How Has Deploying Manifests Since CredHub Changed?

After we converted the appropriate credentials to the `password` and `certificate` types, we can more easily configure deployment secrets to be [automatically rotated](https://builttoadapt.io/the-three-r-s-of-enterprise-security-rotate-repave-and-repair-f64f6d6ba29d).

In addition, adding new properties is easier. We can declare new [BOSH Variables](https://bosh.io/docs/cli-int.html#variables) to generate values for us. BOSH stores the variables in CredHub, so we have one place, automatically, to store our credentials, no human intervention necessary. 
