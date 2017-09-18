---
authors:
- dreeve
- cinnis
categories:
- CredHub
- Operations
- Cloud Foundry
- CF
date: 2017-09-15T19:14:00Z
short: |
  CredHub is designed to store passwords, keys, certificates, and other sensitive information for a BOSH-managed environment. Pivotal's Cloud Operations (CloudOps) team recently migrated credentials for PWS to CredHub. Here's how we did that.
title: Transitioning to CredHub on Pivotal Web Services (PWS)
---

Pivotal's Cloud Operations (CloudOps) team manages deployments to a shared environment, [Pivotal Web Services (PWS)](https://run.pivotal.io); shared in the sense that other teams manage deployments for which PWS is a dependency. To facilitate collaboration and collective ownership, these manifests are maintained in a single repository.

> A litmus test for whether an app has all config correctly factored out of the code is whether the codebase could be made open source at any moment, without compromising any credentials.<br>
> \- [*The Twelve-Factor App*](https://12factor.net/config)

So we can easily update configuration that is variable across deployments (e.g., when rotating credentials, deploying the same manifest to an alternate environment), we keep much of that config stored elsewhere, outside of the manifests.

Historically, CloudOps managed these credentials and such with [`secrets-sanitizer`](https://github.com/pivotal-cloudops/secrets-sanitizer), a tool we built. With the recent introduction of the [BOSH](https://bosh.io) "config server" concept as the (soon-to-be) recommended mechanism for managing variable configuration and, in particular, [CredHub](https://github.com/cloudfoundry-incubator/credhub) as a concrete implementation, we decided to migrate everything to that new (and glorious) world.

Here's how we did that...


## First, a Brief Introduction to...

### `secrets-sanitizer`

In a pre-CredHub world, CloudOps built [`secrets-sanitizer`](https://github.com/pivotal-cloudops/secrets-sanitizer) to extract (or "sanitize") and re-insert (yep, "desanitize") sensitive details from deployment manifests. Given a manifest with properties deemed (via heuristics and configuration) to be "secret", processing that with `secrets-sanitizer` would extract those property values and store them in JSON files, replacing the manifest entries with interpolation placeholders marked as `{{property_key}}`. The sensitive details were then stored elsewhere, in a private repository.

So, given a manifest with the following snippet:

```yaml
properties:
  acceptance_tests:
    api:            api.example.com
    apps_domain:    example.com
    admin_user:     watermelon
    admin_password: apology_cake
```

Running `secrets-sanitizer` against that manifest might look like:

```shell
$ sanitize -i manifest.yml -s ~/production-secrets/
```

Resulting in a manifest with the password extracted and replaced with a `{{placeholder}}`, as such:

```yaml
properties:
  acceptance_tests:
    api:            api.example.com
    apps_domain:    example.com
    admin_user:     watermelon
    admin_password: "{{properties_acceptance_tests_admin_password}}"
```

At deploy-time, the properties were injected into the manifest without being saved. Something like:

```shell
$ bosh deploy <(desanitize -i manifest.yml -s ~/production-secrets/`)
```


### BOSH Interpolation & CredHub

As of v2, the BOSH CLI and Director now have native support for [variable interpolation](https://bosh.io/docs/cli-int.html). When deploying, the variables to be interpolated in the manifest may be satisfied via a number of "value sources". For example:

- a CLI parameter; `bosh <command> --var=VAR=VALUE`
- a `vars-file`; `bosh <command> --vars-file=PATH`
- a `vars-store`; `bosh <command> --vars-store=PATH`
- a "Config Server" implementing an API specified by the BOSH

Given a manifest with the following snippet:

```yaml
admin_password: ((password_variable))
```

Running that manifest through `bosh interpolate` with a parameter as follows:

```shell
$ bosh int manifest --var password_variable=apology_cake
```

Results in:

```yaml
admin_password: apology_cake
```

And, CredHub implements the Config Server API.


## Migrating to CredHub

### Deploying

CredHub is deployed as a BOSH release. Instructions for deployment can be found in the [`credhub-release` documentation](https://github.com/pivotal-cf/credhub-release#deploying-credhub).

We opted to configure CredHub as a colocated Config Server with [UAA](https://docs.cloudfoundry.org/concepts/architecture/uaa.html) as follows:

```yaml
config_server:
  enabled:         true
  url:             "((config_server_endpoint))"
  ca_cert:         "((config_server_ca_cert))"
  uaa:
    url:           "((uaa_endpoint))"
    ca_cert:       "((config_server_uaa_ca_cert))"
    client_id:     credhub_director
    client_secret: "((config_server_uaa_client_secret))"
```


### Importing Credentials

As mentioned above, the `secrets-sanitizer` tool creates JSON files to store credentials. To import those credentials into CredHub, we ran a Ruby script to read from the appropriate JSON file and generate a BASH script to add those credentials to our CredHub.

For example, running this script:

```ruby
#!/usr/bin/env ruby
require 'json'

alias $DEFAULT_INPUT $<
credentials = JSON.parse($DEFAULT_INPUT.read)

STDOUT.puts "#!/usr/bin/env bash"

credentials.each do |key, value|
  output = "credhub set --name /secrets-sanitizer/#{key} --value #{value} --type value"
  STDOUT.puts output
end
```

Results in something like:

```shell
#!/usr/bin/env bash
credhub set --name /secrets-sanitizer/properties_acceptance_tests_admin_password --value apology_cake --type value
```

*Notes:*

- The script reads from "default input" (`STDIN` in our case) and prints the `credhub` CLI commands to `STDOUT`, resulting in a runnable BASH script.
- The `--name` we give each value in CredHub is prefixed with `/secrets-sanitizer`. BOSH implements variable namespacing along the lines of `/bosh-director-name/deployment-name/variable`, so we used `/secrets-sanitizer` as a way of identifying credentials that were loaded using our `secrets-sanitizer` tool.
- CredHub has a handful of [credential types](https://docs.cloudfoundry.org/credhub/credential-types.html), including the generic `value`, as well as more specific types such as `password` and `certificate`. Our initial load imported all credentials as type `value`s. Since the majority of our credentials were named things like `cert` or `password`, a few modifications of the script allowed us to easily create new credentials with the appropriate types.


After loading these values into CredHub, we needed to convert the manifest from the `secrets-sanitizer` format to a BOSH interpolation-friendly format.


### Converting a Deployment to Use CredHub

The manifests we use to deploy [Cloud Foundry](https://www.cloudfoundry.org/) on PWS had been run through the `secrets-sanitizer` tool. As such, the sensitive properties were surrounded by double curly braces.

BOSH variable interpolation uses a similar format, only with parens instead of curly braces. So...

```shell
# given a manifest path,
# - use `sed` to convert curly braces to parens
# - add our prefix to each entry
# - write to STDOUT
sed 's/{{/((\/secrets-sanitizer\//g' manifest.yml | sed 's/}}/))/g' \
  > converted.yml
```

### Deploy

```shell
$ bosh deploy converted.yml
```


## What's Next?


Now that we have converted the appropriate credentials to the `password` and `certificate` types, we will be able to easily configure deployment secrets to be [automatically rotated](https://builttoadapt.io/the-three-r-s-of-enterprise-security-rotate-repave-and-repair-f64f6d6ba29d).

In addition, adding new properties is easier. We can declare new [BOSH Variables](https://bosh.io/docs/cli-int.html#variables) to generate values for us, as opposed to using legacy, custom scripts. And, BOSH stores the variables in CredHub, so we have one place to find and manage our credentials.

