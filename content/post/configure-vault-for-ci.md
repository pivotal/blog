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

{{< responsive-figure src="/images/vault/vault-100.gif" class="center" >}}

# Agenda

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

### Create approle machine user
```bash
# `period` indicates the duration within which the token should be renewed.
# This renewal is done by concourse at an unspecified duration. So we are just
# setting a high value so we don't have to worry about it.
vault write auth/approle/role/my-team-ci period=168h policies=ci
# Fetch the RoleID for the AppRole
vault read auth/approle/role/my-team-ci/role-id
# Get the SecretID issued against the AppRole
vault write -f auth/approle/role/my-team-ci/secret-id
```
As per your concourse deployment, you will need to specify the `role-id`
and `secret-id` along with the `path-prefix`. In this case, the path prefix
should be `secret/ci` since that's what the policy is allowing access to the
approle.


**More Info:**

- [AppRole Auth Method](https://www.vaultproject.io/docs/auth/approle.html)
- [Concourse Vault Configuration](https://concourse-ci.org/creds.html#vault) -
  read last line of this section

## Concourse CI Tooling

Current tooling available:

- [Concourse Vault Resource](https://github.com/wfernandes/vault-resource)
