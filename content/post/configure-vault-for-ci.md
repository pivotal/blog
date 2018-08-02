---
authors:
- warren
categories:
- GCP
- Kubernetes
- Vault
- Credhub
title: "Let's use Vault - Part 3: Setting up Vault"
short: |
  How to configure Vault for your CI
date: 2018-07-29
draft: true
---


# Coming back full circle...Why.
{{< responsive-figure src="/images/vault/full-circle.gif" class="center" >}}

We now to come to the final leg of our journey. We will be integrating
Vault with Concourse CI and exploring some tooling that was built specifically
to make your lives easier.

Traditionally, when you deploy concourse via bosh, it could be deployed with
a secret store like `credhub` such that concourse and any pipelines could
seamlessly access the secrets. **BUT** the team would usually not use that
secret store for any other secrets the team would need. This is another
reason why teams usually took the easy way out by storing secrets in Github.

What we've done here is create a separate store outside the confines of the CI
environment or any other ephermeral environments we create to satisfy our
needs. We now have a single place to keep all our secrets and we can integrate
our tools like CI with that separate secret store.

## Agenda

This is what we are going to be covering in this post.

- [Generating Root Tokens](#generating-root-tokens)
- [Creating AppRole account for machine
  users](#creating-approle-account-for-machine-users)
- [Concourse CI Tooling](#concourse-ci-tooling)


## Generating Root Tokens

In case you deleted the root token as part of your cleanup in a previous blog
post, don't fret! It is quite simple to generate another root token. However,
you will need at least two Pivots to use their unseal keys (assuming the
`--key-threshold=2`)


```bash
otp=$(vault operator generate-root -generate-otp)
vault operator generate-root -otp="$otp"
vault operator generate-root -otp="$otp" --init
# This will prompt for entering the unseal keys to achieve quorum.
# Once that is done, it will display a root token.
vault operator generate-root
```
With the root token you can now `vault login` and perform the root operations
below.

## Creating AppRole Account for Machine Users

Vault provides the `AppRole` auth method to allow *machines* and *apps*
to authenticate against it.

First enable the approle authentication mechanism,
```bash
vault auth enable approle
```

### Create policy for approle

Add the following contents to `/tmp/approle-policy`
```
path "auth/approle/login" {
  capabilities = [ "create", "read" ]
}

path "secret/ci/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
```
As done before create a policy,
```bash
vault policy write ci /tmp/approle-policy
```

Again, be very specific and restrictive. Don't create a single approle user
with permissions to everything. Create separate users per application with
specific policies. This way the impact of leaking an approle token is minimal.

### Create approle machine user
```bash
# `period` indicates the duration within which the token should be renewed.
# This renewal is done by concourse at an unspecified duration. So we are just
# setting a high value so we don't have to worry about it.
vault write auth/approle/role/my-team-ci period=24h policies=ci
# Fetch the RoleID for the AppRole
vault read auth/approle/role/my-team-ci/role-id
# Get the SecretID issued against the AppRole
vault write -f auth/approle/role/my-team-ci/secret-id
# Login to generate an approle token
vault write auth/approle/login role_id=<role-id> secret_id=<secret-id>
```
Depending on how you configure your concourse deployment you will need pieces
of the information above. But you will also need the `path-prefix` set to the
path you made accessible in the policy. In this case, it would be
`/secret/ci`.

**More Info:**

- [AppRole Auth Method](https://www.vaultproject.io/docs/auth/approle.html)
- [Concourse Vault Configuration](https://concourse-ci.org/creds.html#vault) -
  read last line of this section

## Concourse CI Tooling

Concourse itself will store any secrets it uses for its pipelines under
`secret/ci/<team-name>`.

{{< responsive-figure src="/images/vault/what-do-you-do.gif" class="center" >}}

But what if y'all want to access secrets from different paths and not give
the approle access to everything?


{{< responsive-figure src="/images/vault/drumroll.gif" class="center" >}}


Introducing the [Concourse Vault
Resource](https://github.com/wfernandes/vault-resource)!!

We built this resource so that y'all can pull/push secrets directly from
Vault. But more importantly, entire directories.

### Cloud Foundry Example

Most of us use `bbl` to create and destroy environments in our CI. As a side
effect `bbl` generates an entire state directory full of secrets and certs.
Now instead of doing a `put` on a `git` resource to store the state directory
you can use the `vault-resource` to store the entire state directory in Vault.

**More Info:**

- [Concourse Vault Resource](https://github.com/wfernandes/vault-resource)

## Cleanup

{{< responsive-figure src="/images/vault/cleanup-roomba.gif" class="left" >}}
Make sure the root token is revoked as soon as y'all are done using it.

```
vault token revoke <root-token>
```
