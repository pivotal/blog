---
authors:
- warren
categories:
- GCP
- Kubernetes
- Vault
- Credhub
title: "Let's use Vault - Part 1: Deploying Vault"
short: |
  How to deploy Vault on Kubernetes using Google Cloud Storage as its backend
date: 2018-07-21T21:54:40-06:00
draft: true
---

{{< responsive-figure src="/images/vault/fallout.gif" class="center" >}}
# Why are we doing this?

The reason for this post's existence is to encourage more teams to make the
effort to move their credentials, certificates and other relevant *files* -
think `bbl up` to a proper secret store.

Most of us are guilty of taking the easy way out by checking in all our
secrets and certs into a private git repo .  And although we install tools
like the [cred-alert-cli git
hook](https://github.com/pivotal-cf/git-hooks-core/blob/70f9b7dcd4b7ea0617a57d66f23c5716e2028f8e/README.md#installing-cred-alert-cli)
to keep us in check, let us face the reality of our frequent usage of the
`--no-verify` flag.

Eventually our hasty human nature coupled with `--no-verify` will lead us
to expensing the costly mistake of leaking credentials into a repo that is
public or *may become public in the future* - OSS for the win!.

**FACT:** We need to take the stance of not storing any credentials in git.

This post is one of a multi-part post that will be published to help us
deploy, configure and use Vault as part of our workday lives and CI systems.
This will **NOT** be a post to debate the pros and cons of other tools like
`credhub` or `lpass` and how those tools can be used to mitigate this problem.

## Agenda
- [Create bucket and artifacts](#create-bucket-and-artifacts)
- [Configure the helm chart values](#configure-the-helm-chart-values)
- [Helm Install](#helm-install)
- [Other Manual Steps Required](#other-manual-steps-required)

## Create bucket and artifacts
1. Log into your GCP account.
1. Create a service account and restrict its access to the
   `storage.objectAdmin` role.
   - We are going to store the service account key
   in k8s as a secret. Vault will use this key to CRUD secrets into the object
store bucket.
1. Create a bucket in GCS.
   - In this example, we just named it `myteam-vault-bucket`
1. Genereate TLS certs for the ingress service so we can expose it via https.
   - Our team decided to generate certs from [LetsEncrypt](https://www.sslforfree.com/).
   - Follow the instructions to generate the cert for the appropriate domain
     and add the `TXT` record in Route 53.
   - In this example, the URL the cert was generated for was
     `https://myteam.vault.ci.cf-app.com`

## Configure the helm chart values.
There are comments in the config to explain the what and why of the properties.

> ~~~yaml
# We create an Ingress service to expose vault and restrict it to https
# connections.
service:
  type: NodePort
ingress:
  enabled: true
  hosts:
  - myteam.vault.ci.cf-app.com
  annotations:
    kubernetes.io/ingress.allow-http: false
  tls:
  - hosts:
    - myteam.vault.ci.cf-app.com
    # The LetsEncrypt signed certs are stored as a k8s secret as well.
    secretName: vault-tls
vault:
  # By default the Vault Helm Chart will install in dev mode. Make sure to
  # turn this `dev` mode off!!
  dev: false
  customSecrets:
  # This secret will be uploaded into k8s as part of the Installation.
  - secretName: vault-gcs-service-account
    mountPath: /vault/sa
  config:
    api_addr: "https://myteam.vault.ci.cf-app.com"
    storage:
      gcs:
        bucket: myteam-vault-bucket
        ha_enabled: \"true\"
        credentials_file: /vault/sa/key.json
~~~

## Helm Install

```bash
export NAMESPACE_NAME="myteam-vault"
kubectl create namespace "$NAMESPACE_NAME"

kubectl create secret generic vault-gcs-service-account \
    --from-file=key.json="/tmp/sa.json" \
    --namespace "$NAMESPACE_NAME"

kubectl create secret tls vault-tls \
    --cert "/tmp/vault-tls.crt" \
    --key "/tmp/vault-tls.key" \
    --namespace "$NAMESPACE_NAME"

helm repo add incubator \
    http://storage.googleapis.com/kubernetes-charts-incubator

helm install incubator/vault \
    --name vault \
    --values "/tmp/helm-config-values.yml" \
    --namespace "$NAMESPACE_NAME"
```

## Other Manual Steps Required

After vault is deployed we need to manually edit the ingress service.
See the github issue below descrbing the reason for this change.

This will show you the ingress service.
```
kuebctl get ingresses --namespace $NAMESPACE_NAME
```
By default the name of the ingress will be `<ReleaseName>-<ChartName>` which
in this case will be `vault-vault`. If you'd like to override it, specify the
property `nameOverride` in the helm config.

Edit the ingress service and remove `path: /`
```
kubectl edit ingresses vault-vault --namespace $NAMESPACE_NAME
```

**More Info:**

- [`nameOverride`](https://github.com/helm/charts/blob/e64ba7aa8b2743715e0177dfc78a3a070e3a2b2d/incubator/vault/templates/_helpers.tpl#L13): If you'd like to override the ingress service name.
- [Github Issue](https://github.com/helm/charts/issues/6719): the reason we have to remove `path: /`

---
{{< responsive-figure src="/images/vault/tada.gif" class="center"
title="Tada!!" >}}

You may now target your vault using the `vault` CLI
```bash
export VAULT_ADDR=https://myteam.vault.ci.cf-app.com
vault status
```
Understandably this is a bit of a 🐔 and 🥚 problem where we need some
secrets to stand up our secret store. We've decided to store these secrets in
LastPass.

## Cleanup

{{< responsive-figure src="/images/vault/cleanup-chris.gif" class="left" >}}

- Make sure to destroy sensitive information like the service account key and
certs from your local machine.
- Remove the `TXT` record from Route 53 once the domain has propogated.

## Next...

Let's [configure vault for your team]({{< ref "configure-vault-for-team" >}})
