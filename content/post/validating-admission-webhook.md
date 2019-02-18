---
authors:
- warren
categories:
- Kuberentes
- CRD
- Custom Resource
date: 2019-02-09
draft: true
short: |
  This post explains how to setup validation for your custom reosurce definition with the Validating Admission Webhook
title: Custom Resource Validation with Admission Webhooks
---

# Introduction

One way to extend the Kubernetes platform is by building custom controllers
that operate on custom resources. We can leverage custom resources to enhance
the cluster with features for users interacting with it.

Now, why do we care so much about validating your custom resources? Because of
**user experience**. When users interact with our custom resources we have the
ability to provide them direct feedback on whether or not they've authored a
valid custom resource thus removing any frustration they may have later on
when they have to troubleshoot why their stuff isn't working.

This post will delve into how we can provide a great **user experience** by
simply building out good validation for our custom resources.

**Agenda**

- [Nomenclature](#nomenclature)
- [Basic validation within the CRD](#basic-validation)
- [Webhook validation](#webhook-validation)
  - [ValidatingWebhookConfiguration](#validatingwebhookconfiguration)
- [Conclusion](#conclusion)

## Nomenclature

**CRD - Custom Resource Definition**

A [CRD][custom-resource-def] is the template of the object that you are
working with. When a CRD is applied towards a `kube-apiserver` you are
essentially telling the Kubernetes API that it will need to understand
instances of this type of object. It will then serve and handle the storage of
your custom resource instances. This is an example of a custom resource
definition.

```yaml
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: logsinks.observability.knative.dev
spec:
  group: observability.knative.dev
  version: v1alpha1
  versions:
    - name: v1alpha1
      served: true
      storage: true
  scope: Namespaced
  names:
    plural: logsinks
    singular: logsink
    kind: LogSink
```

**CRI - Custom Resource Instance**

A [custom resource][custom-resource] is an instance of a CRD.

```yaml
apiVersion: observability.knative.dev/v1alpha1
kind: LogSink
metadata:
  name: valid-syslog-hostname
spec:
  type: syslog
  host: example.com
  port: 12345
```

**Custom Controller**

A [custom controller][custom-controller] is a controller that can be deployed
and updated in a cluster and work with custom resource instances when they've
been created, updated or deleted.


# Basic Validation

[Basic validation][basic-validation] of properties is made possible via the
OpenAPI v3 schema. This validation is great for specifying the correct format
of the spec properties and can be specified directly within the CRD.

```yaml
...
spec:
  ...
  validation:
    openAPIV3Schema:
      properties:
        spec:
          required:
          - type
          - port
          - host
          properties:
            port:
              type: integer
              minimum: 0
              maximum: 65535
            type:
              type: string
              enum:
              - syslog
            host:
              type: string
              pattern: '^([a-zA-Z0-9-\.]+)$|^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$|^([a-fA-F0-9\:]+)$'
            enable_tls:
              type: boolean
            insecure_skip_verify:
              type: boolean
...
```

# Webhook Validation

By using Validating Admission Webhooks we can provide a deeper level of
validation for your custom resources. For example, if your custom resource
specifies an external service, we can validate if that service is up and
running and ready to integrate with your application.

The ValidatingAdmissionWebhook is simply an HTTP callback that accepts
admission requests and returns an admission response if the request is
valid.

## ValidatingWebhookConfiguration

The `ValidatingWebhookConfiguration` is the config that is required to tell
the kubernetes API that when it gets certain objects it needs to forward the
request to our validation service. Let's try and break down the following
`ValidatingWebhookConfiguration`.

```yaml
apiVersion: admissionregistration.k8s.io/v1beta1
kind: ValidatingWebhookConfiguration
metadata:
  name: validator.observability.knative.dev
webhooks:
  - name: validator.observability.knative.dev
    rules:
      - apiGroups:
          - "observability.knative.dev"
        apiVersions:
          - v1alpha1
        operations:
          - CREATE
          - UPDATE
        resources:
          - clustermetricsinks
    failurePolicy: Fail
    clientConfig:
      service:
        name: validator
        namespace: knative-observability
        path: /metricsink
      caBundle: ""
```

1. The `rules` describe what operations need to be applied towards which
resources. In this case, we only care about `CREATE` and `UPDATE` operations
on the `clustermetricsink` resource under `observability.knative.dev/v1alpha1`.

1. The `failurePolicy` describes the behavior you want if for some reason the
kubernetes API isn't able to contact the validation service. It can take two
values, `Ignore (default)` or `Fail`. In this case, we want to reject any
request for creating or updating `clustermetricsinks` if the validation
service is down.


1. The `clientConfig` describes the information needed to connect to the
validation service/application.


### Gotchas!
One of the reasons I felt the need to write this post were for the following
caveats.

1. If the validation is hosted outside the cluster, then the `clientConfig`
   should have the `url` property set instead of the `service`. However, if
the service is hosted within the cluster, then just specify the name,
namespace and the path of the HTTP service in the cluster. [Kelsey
Hightower][kelsey-hightower] wrote a simple post to get started with
validating webhooks and Cloud Functions.
1. Currently, the validation service must be hosted on an [HTTPS service and on
   port 443][admission-webhook-constraints]. However, there are is an open prposal to remedy these
constraints. [See this Kubernetes Enhancement Proposal for more
info][admission-webhook-ga-kep].
1. There is a known bug that the `caBundle` property is required and cannot be
   omitted from the config. So if you remove that property, it will error on
create. However, if you aren't sure as to what the `caBundle` for the endpoint
will be at time of creation you can leave it empty. [This Github
issue][admission-webhook-ca-bundle] tracks the use-case of referencing a
secret or configmap for the `caBundle` instead of using a base64 encoded
string.

# Conclusion

Once you've setup your validation webhook configuration and create your
resources you can now immediately get confirmation if the resource applied was
correct or not.

```bash
$ kubectl apply -f invalid-sink.yaml
Error from server: error when creating "invalid-sink.yaml": admission webhook "validator.observability.knative.dev" denied the request: Failed to validate metricsink config
```


[custom-controller]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-controllers
[custom-resource-def]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#customresourcedefinitions
[custom-resource]: https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/#custom-resources
[basic-validation]: https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/#validation
[admission-webhook-constraints]: https://github.com/kubernetes/kubernetes/blob/a9fd9cef765a0b6d3854b187dcb6d05097f50c6a/pkg/apis/admissionregistration/types.go#L256-L274
[admission-webhook-ga-kep]: https://github.com/mbohlool/enhancements/blob/8ec8779489e10af72823e3ef317951c138c493d1/keps/sig-api-machinery/00xx-admission-webhooks-to-ga.md#port-configuration
[kelsey-hightower]: https://github.com/kelseyhightower/denyenv-validating-admission-webhook
[admission-webhook-ca-bundle]: https://github.com/kubernetes/kubernetes/issues/72944
