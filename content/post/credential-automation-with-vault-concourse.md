---
authors:
- dlapiduz

categories:
- Concourse
- Vault
- Automation
date: 2017-08-08T12:37:22Z
draft: true
short: |
  How to use Vault to securely store and rotate credentials for Concourse pipelines.
title: Secure credential automation with Vault and Concourse
---

If you want a tool to help with continuous integration and continuous delivery that has a simple but deterministic approach you probably heard of [Concourse](https://concourse.ci).

Concourse is a great tool to run all your continuous delivery pipelines and it allows multiple people to work on their flow by making pipelines configuration as code (all pipelines and task definitions are YAML files).

That said, one of the most common complains about concourse is how credential management is handled. Most pipelines will need "secrets" to operate. They might be a password, an SSH key, TLS certificates or any other number of attributes required for deployment.

Concourse allows for the (parametrization of pipelines)[https://concourse.ci/fly-set-pipeline.html#parameters] when you `fly` them but it will store the pipeline and the secrets in the database as one single encrypted field.

This might work in some environments but if you need to create an extra layer of security, be it for compliance reasons and/or for better security practices) you need to be able to split these secrets from the Concourse pipeline. 

That is the reason why the Concourse team created a (Credential Management)[https://concourse.ci/creds.html integration. It's first implementation is an integration with (Vault)[https://www.vaultproject.io/] and we are going to explore in this post how to get started.

Moreover, there is an often overlooked aspect of distributed systems security where Concourse and Vault can help. Credential rotation is crucial to keeping systems secure and we can use these tools to remove human intervention and automate the rotation of credentials.

### Getting Started

#### Requirements:
- Concourse (http://concourse.ci/installing.html) - We are assuming it is BOSH installed in this post but it is not required.
- Vault (https://github.com/cloudfoundry-community/vault-boshrelease)

### Create a Vault read-only token for Concourse

We will need a read only token for Concourse so it can access the Vault secrets. First, we have to create the Vault policy:

1. Login to Vault:
  ` $ vault auth <token> `
1. Create a file with the policy: 
    ```concourse.hcl
    # concourse.hcl
    path "/concourse/*" {
      capabilities = ["read", "list"]
    }
    ```
1. Upload the policy to Vault:
  ` $ vault write sys/policy/concourse rules=@concourse.hcl ` 
1. Create a periodic token:
  ` $ vault token-create -period="2h" -orphan -policy=concourse`

Store the token since we will use it in the Concourse manifest.


### Connect Concourse to Vault

Setting up Concourse to use Vault for credential management is very straightforward given the new integration. You just have to pass in some parameters in the Concourse manifest to enable the communication. Here is an example:

```
- ...
  instances: 1
  jobs:
  - name: atc
    properties:
      ...
      vault:
        auth:
          client_token: <TOKEN FROM PREVIOUS STEP>
        tls:
          ca_cert:
            certificate: |-
              -----BEGIN CERTIFICATE-----
              <VAULT CA CERTIFICATE>
              -----END CERTIFICATE-----
        url: <VAULT URL/IP>
    release: concourse
 ```

Once you add this section to the manifest Concourse should now be able to read from Vault.

### How to use it?

To use Vault secrets in Concourse pipelines you have to parametrize your pipeline with parentheses `(())` instead of curly brackets `{{}}`. Concourse currently supports only one credential management system at a time with one set of credentials, so if you specify a parameter, it will look it up in the instance you linked Concourse to.

Not everything in a pipeline can be parametrized, you can read more about what can be parametrized in the Concourse docs: http://concourse.ci/creds.html#what-can-be-parameterized. Basically you can pull secrets in `source` or `params` sections of a pipeline.

Here is an example:
Let's say we have a pipeline that deploys an application to  Pivotal Cloud Foundry. You will need a resource that has the credentials to be able to push the app. This is what it would look like:
```
resources:
- name: resource-deploy-web-app
  type: cf
  source:
    api: https://api.run.pivotal.io
    username: ((cf_username))
    password: ((cf_password))
    organization: ((cf_organization))
    space: ((cf_space))
    skip_cert_check: false
```

If we set the pipeline on the team `main` with the name `deploy-app`. Concourse will look in Vault for `/concourse/main/deploy-app/cf_username` first and `/concourse/main/cf_username` second.

### How do you rotate credentials then?

Vault doesn't currently support random credential generation or versioning of secrets. Because of that we have to be careful when writing new secrets to Vault.

If the secret that we are writing to Vault is not the currently valid one we will lose track of it.

To rotate credentials we can then create a script or a pipeline that does it for you. We are not going to go into the details of it but it'd basically do this:

- Create a new random secret
- Store it into Vault with a suffix (like: `/concourse/main/cf_password_new`)
- Change the secret in the service (in this case run `cf passwd`)
- Store it into Vault again with the full name (`/concourse/main/cf_password`)

This way you can rotate credentials without having to worry about all the places you have to change it. Once it is stored in Vault all other services should be able to reference it from that point forward.
**Concourse will not require to be notified about this change, it will just use the latest secret from Vault**. 

### Wrapping up

Managing secrets shouldn’t have to be painful and you can now have a setup that completely automates this problem away. Concourse and Vault can dramatically improve your security posture by removing the manual processes of credential rotation.
Adding a secrets store will increase operational complexity but it will also help your team have better security practices.
