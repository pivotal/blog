---
authors:
- warren
categories:
- GCP
- Kubernetes
- Vault
- Credhub
title: "Let's use Vault - Part 2: Setting up Vault"
short: |
  How to configure Vault for your team
date: 2018-07-28
---

# Open Sesame!!

This post provides a guideline of simplest commands that are required to setup
vault locally for your team instead of having to wade through all of
Hashicorp's extensive documentation.

{{< responsive-figure src="/images/vault/vault-open.gif" class="center" >}}

## Agenda

This is what we are going to cover in this post:

- [Initialize the Vault](#initialize-the-vault)
- [Unsealing the Vault](#unsealing-the-vault)
- [Upgrade Secrets Engine](#upgrade-secrets-engine)
- [Create user accounts for team members](#create-user-accounts-for-team-members)
- [Next...Configure Vault for your CI]({{<
ref "configure-vault-for-ci" >}})

## Initialize the Vault

To make sure everything is working,
```bash
export VAULT_ADDR=<https://vault.myteam.ci.cf-app.com>
vault status
```

When vault first starts up it is in a *sealed* state. As part of the
initialization process, the operators need to generate unseal keys so they can
*unseal* the vault.

We would love to go into more detail but we doubt we could get any clearer than
what was written up by Hashicorp themselves. So come back to this post after
y'all have read [their doc on initializing vault](https://www.vaultproject.io/intro/getting-started/deploy.html#initializing-the-vault).


{{< responsive-figure src="/images/vault/welcome-back.gif" class="small center" alt="welcome-back" >}}

So this is what we suggest doing when genereating the unseal keys for Vault.

```bash
vault operator init --key-shares=<number-of-team-memebers> --key-threshold=2
```
This command outputs the unseal keys and an initial root token which will be
used to generate users and policies for Vault. Distribute the unseal keys to
the respective team memebers via LastPass.

Having a threshold of two ensures that at least two Pivots are required to
generate root tokens in the future to perform root operations.

## Unsealing the Vault
As mentioned in their docs, the vault is sealed upon start. So we'll have to
use the unseal keys to open the vault.

```bash
vault operator unseal
```
**Interesting:** The unsealing can be performed by multiple users on
multiple machines since it is a stateful operation as long as each user is
pointing to the same vault.

After the vault has been unsealed, you can login with the root token.
```bash
vault login
```

## Secrets Engines

By default vault has the following secret engines available.
```bash
$ vault secrets list
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_b175a479    per-token private secret storage
identity/     identity     identity_6dc092df     identity store
secret/       kv           kv_cb795fa8           key/value secret storage
sys/          system       system_f29e7832       system endpoints used for control, policy and debugging
```
Although, we can very easily add another key/value secret engine, we are going
to use `secret/` for our team sharing purposes. By default `secret/`
is KV secret engine v1 which doesn't provide versioning or ability to roll
back secrets.

```bash
# Check the verison of current `secret/` engine. You should see an object
# "options": { "version": "1" }
vault kv get -format=json -field=secret/ /sys/mounts/
# OR
vault secrets list -format=json
```

**NOTE:**

We are not upgrading our KV Engine to v2 because at the time of writing this
post, Concourse doesn't support retrieval of secrets from the vesioned engine
(KV Engine v2).

**More Info:**

- [Versioned secrets introduced in Vault v0.10](https://www.vaultproject.io/guides/secret-mgmt/versioned-kv.html).

## Create user accounts for team members

### Enable userpass authentication
Vault supports multiple ways allowing users to authenticate against it.
For our purposes, we will be using the `userpass` auth method, which is simply
a username/password combination.

```bash
# View the current authentication methods. Initially, there should only be `/token`
vault kv get sys/auth
# Enable userpass auth
vault auth enable userpass
# This should show `/userpass` in the list now.
vault kv get sys/auth
```
**More Info:**

- [Other authentication methods](https://www.vaultproject.io/docs/auth/index.html)

### Create policies for users

Before we actually create the user accounts we want to define some user
policies that will allow the users to write to `secret/`.

Write the following contents into a file `/tmp/devs-policy`

```
path "secret/*" {
  capabilities = ["create", "read", "list", "update"]
}
```

Then create the policy in vault
```bash
vault policy write devs /tmp/dev-policy
vault policy list
vault policy read devs
```

### Create users

```bash
vault kv put auth/userpass/users/<username> policies=default,devs password=<generate-a-password>
```
Yes, the operator creating the users must be trusted to generate the passwords
for the rest of the team members. And unfortunately, there isn't a way to
force users to regenerate their passwords.

However, we decided that this `userpass` auth method is still better than
[`github` auth](https://www.vaultproject.io/docs/auth/github.html) which allows
any personal access token that belongs to the user to be used for
authentication.

**More Info:**

- These issues have more details on the password reset limitation:
[Issue 1](https://groups.google.com/forum/#!topic/vault-tool/15O9GzGAsLw),
[Issue 2](https://groups.google.com/forum/#!topic/vault-tool/gEONXuCsJFc)

#### Login

```bash
# Login with the username
vault login -method=userpass <username>
# Displays information about the token or accessor
vault token lookup
```

#### Logout
```bash
vault token revoke -self
```

## Cleanup

{{< responsive-figure src="/images/vault/cleanup-cat.gif" class="left" >}}
If you think you are done configuring Vault, then you should delete the root
token.
```bash
vault token revoke <root-token>
```
## Next...

We will go into details for how to [configure vault for your concourse CI]({{<
ref "configure-vault-for-ci" >}})


