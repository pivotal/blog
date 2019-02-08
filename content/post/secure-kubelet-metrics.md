---
authors:
- warren
categories:
- Kubernetes
- Logging & Metrics
date: 2019-02-02
draft: true
short: |
  This post describes how to read kubelet metrics securely via port 10250
title: Kubelet Metrics The Correct Way!
---

# Introduction

The kubelet exposes many useful metrics that can be used for a variety of
purposes. These metrics are already being scrapped by components like the
Metric Server.

The metrics from the /stats/summary include cpu, memory, rootfs and log
metrics for every container running on the node which can be very helpful to
track the health of each node.

However, since these metrics can also contain sensitive information about the
containers running, access to them have been rightously cordoned off and now
the read-only port 10255 has been deprecated.

**Table of Contents**

- [Insecure Read-Only Port 10255](#insecure-read-only-port-10255)
- [Secure Port 10250](#secure-port-10250)
  - [Using Service Account Bearer Tokens](#using-service-account-bearer-tokens)
  - [Using Client Certificates](#using-client-certificates)


# Pre-requisites

For this post, we are going to be working with a single node v1.11 GKE cluster
for which we have cluster-admin access.

The first thing before we go down this path is to take a look at the official
documentation for [Kubelet Authentication and
Authorization][kube-authn-authz].
We want to make sure that the kubelet in your cluster is configured correctly
in the first place.

Below is a snippet from the `/home/kubernetes/kubelet-config.yaml` on a GKE
worker node.

```
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: false
  x509:
    clientCAFile: /etc/srv/kubernetes/pki/ca-certificates.crt
authorization:
  mode: Webhook
readOnlyPort: 10255
```
The above configuration provides:

- No anonymous authentication requests for port 10250
- However the readOnlyPort is enabled at 10255
- Client certificate authentication is enabled
- Webhook authentication is disabled

For the purpose of this demonstration, we actually want webhook authorization
to be enabled. Follow, the following steps to enable it.

## Enabling webhook authorization on GKE worker node

1. Get the node name

    ```bash
    kubectl get nodes
    ```

1. SSH onto the GKE node and become root

    ```bash
    gcloud compute ssh <NODE_NAME> --zone <ZONE>
    sudo -i
    ```
1. Edit the `kubelet-config.yaml`

    ```bash
    vim /home/kubernetes/kubelet-config.yaml
    ```
1. Enable webhook authentication

    ```bash
    ...
    webhook:
      enabled: true
    ...
    ```
1. Restart the kubelet

    ```
    systemctl restart kubelet
    ```
1. Get out!


# Insecure Read-Only Port 10255
As of the time of writing this post, the kubelet still exposes these metrics
via a read-only port of `10255`.  This can be conveniently accessed via a
simple `curl` if you are on the node or via the following pod config.

1. Apply the following pod configuration

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: nginx
      labels:
        app: nginx
    spec:
      hostNetwork: true
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 10255
    ```
1. Exec onto the pod and install utils

    ```bash
    kubectl exec -it nginx /bin/bash
    apt update && apt install curl -y
    curl http://localhost:10255/stats/summary
    ```

# Secure Port 10250
## Using Service Account Bearer Tokens

In order to get the kubelet metrics from within the cluster you may use the
service account bearer token to authenticate requests with the kubelet. This is
possible because we've enabled webhook authentication.


```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubelet-api
rules:
- apiGroups: [""]
  resources: ["nodes/stats", "nodes/metrics", "nodes/log", "nodes/spec", "nodes/proxy"]
  verbs: ["get", "list" ]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: test-kubelet-api
subjects:
- kind: ServiceAccount
  name: nginx
  namespace: default
roleRef:
  kind: ClusterRole
  name: test-kubelet-api
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  hostNetwork: true
  serviceAccountName: nginx
  containers:
    - name: nginx
      image: nginx
```

Once the configuration above has been applied, exec onto the pod and run the
following:

```bash
kubectl exec -it nginx /bin/bash
apt update && apt install curl -y
curl https://localhost:10255/stats/summary -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" -k
```

Y'all should be able to get the same json payload as from the `readOnlyPort`.

## Using Client Certificates

### On the Node
In order to get access to the kubelet metrics while outside the cluster you may
want to use the client certificate authentication method.

From the `kubelet-config.yaml` above we can see that the kubelet is configured with a client CA file.
```
  x509:
    clientCAFile: /etc/srv/kubernetes/pki/ca-certificates.crt
```

We can simply use the certs in this directory, to access the kubelet metrics.

```
cd /etc/srv/kubernetes/pki/
curl https://localhost:10250/stats/summary  --cacert ca-certificates.crt --cert kubelet.crt --key kubelet.key -k
```

But this is not terribly useful now is it! So next let's see how we can use
client certificate authentication to access while in the cluster.

### In the Cluster

As per [the docs][kubelet], any request presenting this client certificate
signed by one of the authorities in the client-ca-file is authenticated with an
identity corresponding to the CommonName of the client certificate.

From the [Kubernetes Authentication Docs][k8s-auth-docs] we can see how x509
certificates map to users and groups.

> CN --> User

> O --> Group

So let's find out the common name of the certificate on the GKE worker node.

```bash
openssl x509 -in /etc/srv/kubernetes/pki/kubelet.crt -text -noout

# Output
...
Subject: CN=kubelet
...
```
This corresponds to:

```yaml
kind: ClusterRoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubelet-api
subjects:
- kind: User
  name: kubelet
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: kubelet-api
  apiGroup: rbac.authorization.k8s.io
```

If the client cert had a Subject with `O=system:nodes` for example, then the
ClusterRoleBinding would be:


```yaml
kind: ClusterRoleBinding
  apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubelet-api
subjects:
- kind: Group
  name: system:nodes
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: kubelet-api
  apiGroup: rbac.authorization.k8s.io
```

**TODO** SHOW HOW TO USE


# Bonus
- TODO: how to configure telegraf to use 10250

# References
- This [Githhub issue comment][github-issue] helped me put everything together.

[kube-authn-authz]: https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-authentication-authorization/
[kubelet]: https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
[github-issue]: https://github.com/poseidon/typhoon/issues/215#issuecomment-388703279
[k8s-auth-docs]: https://kubernetes.io/docs/reference/access-authn-authz/authentication/#x509-client-certs
