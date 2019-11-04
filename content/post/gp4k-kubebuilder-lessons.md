---
authors:
- dsharp
- jvigil
- khuddleston
- gtadi
categories:
- Greenplum
- Kubernetes
- KubeBuilder
date: 2019-10-14T16:00:00Z
draft: true
short: |
  Lessons we learned while building a controller with KubeBuilder
title: How we built a controller using KubeBuilder with Test Driven development, Part 1
image: /images/pairing.jpg

---

## Who are we?

We are the Greenplum for Kubernetes team. We're working on a Kubernetes operator
to run [Greenplum](https://greenlpum.org), and connected components of Greenplum
like [PXF](https://gpdb.docs.pivotal.io/5220/pxf/overview_pxf.html) and
[GPText](https://gptext.docs.pivotal.io/330/welcome.html). We started with a
controller for Greenplum, and recently used
[KubeBuilder](https://github.com/kubernetes-sigs/kubebuilder) to add controllers
for PXF and GPText.

In this post, we review some of the key lessons we learned in the course of
developing our KubeBuilder controllers. In
[_Part 2_](/post/gp4k-kubebuilder-tdd), we cover our journey of discovery of how
to unit test our new controllers.

## Background

The [Kubernetes operator pattern][k8s-operator] is used to extend Kubernetes
with custom resources and APIs. An operator can declare a resource by submitting
a [_CustomResourceDefinition_][k8s-crd] to the api-server, and implement a
control loop to listen for changes to those resources and react as necessary to
manage underlying resources, which may be other Kubernetes resources, or
entirely new resources like an external storage system.

Our first controller for Greenplum was implemented using the Kubernetes code
generators, workqueue, and hand-written code to react to create, update, and
delete events from the _Informer_. This controller contains a lot of boilerplate
and did not make it easy to follow some of the controller best practices. The
greatest example of this is that we reacted to create, update, and delete in
different ways, making our controller [edge driven rather than level
driven][oreilly-edge-level]. While we haven't experienced any issues with it
thus far, edge triggering could make our controller less resilient should we
find ourselves in unexpected states.

[KubeBuilder](https://github.com/kubernetes-sigs/kubebuilder) is a framework for
building operators that integrates controller-runtime to implement a lot of the
[responsibilities of an operator and its controllers][inside-controller][^1],
including watching for resources, rate-limiting the control loop to reduce the
chances of overloading the controller, and caching objects. Instead of relying
on generated clients for custom types, KubeBuilder uses the controller-runtime
client that works with any type registered. KubeBuilder generates scaffolding
for controllers that need only one function implented: `Reconcile()`. This made
it much simpler for us to incorporate the best-practice controller principles
into our new controllers.

[k8s-operator]: https://kubernetes.io/docs/concepts/extend-kubernetes/operator/
[k8s-crd]: https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/
[oreilly-edge-level]: https://www.oreilly.com/library/view/programming-kubernetes/9781492047094/ch01.html#edge-vs-level
[inside-controller]: https://speakerdeck.com/govargo/inside-of-kubernetes-controller
[^1]: [This slide deck][inside-controller] from _Kubernetes Meetup Tokyo_ is a
    great overview based on the O'Reilly book _Programming Kubernetes_ of what a
    K8s controller needs to do, and gives a sense of all the things that
    KubeBuilder takes care of for you.

## Building the Controller

The [KubeBuilder](https://book.kubebuilder.io/) book covers in detail [how to
write a simple controller][kb-book-controller-impl]. Despite the thoroughness of
the book, there were some key points that tripped us up.

[kb-book-controller-impl]: https://book.kubebuilder.io/cronjob-tutorial/controller-implementation.html

### Controller Basics

Our use case is a simple _CustomResourceDefinition_ to parameterize construction
of a _Deployment_ and _Service_. After the reconciler is registered with the
controller-runtime _Manager_, then its `Reconcile()` method will be called any
time an object needs to be updated. The controller manager takes care of the
basic controller details like listing and watching for changes to the objects,
caching retrieved objects, and queuing and rate limiting reconciliations. When
it determines that a change may need to be made, it calls the registered
reconciler. The `reconcile.Request` parameter to `Reconcile()` contains only the
namespace and name of the object to be reconciled. So, the first step is to Get
the object. Then, based on its current contents, we can construct the desired
state of our dependent objects (Deployment, Service), and ensure the desired
state is set for those objects in the apiserver.

Setting that desired state correctly and succinctly took us a few iterations,
so below are some key details that we learned in the process, and finishing
with an example Reconcile implementation.

### CreateOrUpdate

_[CreateOrUpdate]_ is a helper method provided by controller-runtime. It does
what it says on the tin: Given an _Object_, it will either _Create_ it or
_Update_ an existing object. Because of this functionality, it can be used for
your dependent objects, and forms the core of many `Reconcile()` functions.
However, its API makes it extremely easy to misuse without understanding some of
its internals.

`CreateOrUpdate()` takes a callback, "mutate", which is where all changes to the
object must be performed. This point bears repeating: your mutate callback is
the only place you should enact the contents of your object, aside from the name
and namespace which must be filled in prior. Under the hood, _CreateOrUpdate_
first calls `Get()` on the object. If the object does not exist, `Create()` will
be called. If it does exist, `Update()` will be called. Just before calling
either `Create()` or `Update()`, the mutate callback will be called.

> **`CreateOrUpdate(ctx, client, obj, mutate)`**<br>
> `client.Get(obj)`<br>
> `mutate(obj)`<br>
> If `obj` did not exist, `client.Create(obj)`<br>
> If `obj` did exist, `client.Update(obj)`<br>

Initial testing may appear to work if you pass a no-op mutate and instead
prepare `obj` before calling _CreateOrUpdate_. When the client has no object to
return, because it does not exist as in the `Create()` path, `Get()` does not
modify `obj`, and `obj` will remain as it was before entering _CreateOrUpdate_.
The object would get passed to `Create()` in the same state as it was before
_CreateOrUpdate_ was called. However, an issue arises during `Update()`. If the
object exists (as in the `Update()` path), then `Get()` overwrites `obj`,
merging the server's content over any content that was pre-filled. The
`Update()` will never do anything, even if the actual object has diverged from
the desired state. Therefore proper usage of "mutate" is essential to reconcile
the object.

In your mutate callback, you should surgically modify individual fields of the
object. Don't overwrite large chunks of the object, or the whole object, as we
tried to do initially. Overwriting the object would discard the `metadata`
field, and cause _Update_ to fail, or overwrite the `status` field, losing
state. It could also interfere with other controllers trying to make their own
modifications to the object. Remember, you are only one controller in the whole
Kubernetes cluster&mdash;play nice with others.

[CreateOrUpdate]: https://github.com/kubernetes-sigs/controller-runtime/blob/v0.2.2/pkg/controller/controllerutil/controllerutil.go#L124

### Garbage Collection, OwnerReferences and ContollerRefs

The _OwnerReferences_ field within the metadata field of all Kubernetes objects
declares that if the referred object (the owner) is deleted, then the object
with the reference (the dependent) should also be deleted by [garbage
collection][k8s-gc]. A controller should create a
[ControllerRef][k8s-controllerref] (an OwnerReference with `Controller: true`)
on objects it creates. There can be only one ControllerRef on an object in order
to prevent controllers from fighting over an object.

For example, an `ownerReferences` entry is added to a Deployment that was
created by a CustomResource controller, so that when the given CustomResource
is deleted, the corresponding Deployment is also deleted.

The `controller-runtime` package provides another method,
_[SetControllerReference]_, to add a ControllerRef to objects that a controller
creates. It takes care of correctly appending to existing OwnerReferences and
checking for an existing ControllerRef.

If we call SetControllerReference() on all objects we create during
Reconcile(), then we can rely on the garbage collector, and we do not need to
detect a deleted CR to delete its sub-resources.

[k8s-gc]: https://kubernetes.io/docs/concepts/workloads/controllers/garbage-collection/
[k8s-controllerref]: https://github.com/kubernetes/community/blob/master/contributors/design-proposals/api-machinery/controller-ref.md
[SetControllerReference]: https://github.com/kubernetes-sigs/controller-runtime/blob/v0.2.2/pkg/controller/controllerutil/controllerutil.go#L56

### Returning an error from Reconcile means requeue

Errors returned from `Reconcile()` will be logged. But returning an error from
`Reconcile()` also means the reconciliation will be requeued. If that's not
desirable, don't return an error. This means thinking carefully about simply
returning downstream errors.

When an [error is returned from `Reconcile()`][kb-reconcileHandler], KubeBuilder
logging of the error is very verbose, and includes a stack trace. The verbose
log message may be difficult for a user to parse. Our experience with this was
for a _Secret_ that needs to be provided by the user for the PXF service to
operate properly. If that _Secret_ is missing (perhaps it was `kubectl apply`-ed
at the same but not available in the API yet), then we would return the error we
got from `Get()`-ing the _Secret_. We did want the reconciliation to be
requeue'd since we are not watching the _Secret_ resource and would not
otherwise reconcile again once the _Secret_ did get created. To silence the
stack trace, we decided to instead log a helpful error message, and return a
`Result` with `Requeue` set to `true`.

[kb-reconcileHandler]: https://github.com/kubernetes-sigs/controller-runtime/blob/v0.2.2/pkg/internal/controller/controller.go#L216

### Ignore NotFound errors

Case in point for not returning an error: A subtlety in the KubeBuilder book
is how they ignore NotFound errors when `Get()`ting the reconciled object.
Normally NotFound would be returned when the object has been deleted. Since we
have arranged for the garbage collector to clean up our dependent objects,
there is no need to do anything with NotFound errors, so we can ignore them. If
the reconciled object was not deleted, but missing for some other reason, we
should still ignore NotFound errors. We do not want to requeue the
reconciliation by returning the error. If the object were to reappear in the
API, the controller would get another reconciliation at that time. Requeuing
the reconciliation would be a waste of time.

### Example

To put all of the above together, here is a simplified example of Reconcile():

```go
import (
	"github.com/pkg/errors"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
)

func (r *CustomReconciler) Reconcile(req ctrl.Request) (ctrl.Result, error) {
	ctx := context.Background()
	// Get CustomResource
	var customResource myApi.CustomResource
	if err := r.Get(ctx, req.NamespacedName, &customResource); err != nil {
		if apierrs.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, errors.Wrap(err, "unable to fetch CustomResource")
	}

	// CreateOrUpdate SERVICE
	var svc corev1.Service
	svc.Name = customResource.Name
	svc.Namespace = customResource.Namespace
	_, err := ctrl.CreateOrUpdate(ctx, r, &svc, func() error {
		ModifyService(customResource, &svc)
		return controllerutil.SetControllerReference(&customResource, &svc, r.Scheme)
	})
	if err != nil {
		return ctrl.Result{}, errors.Wrap(err, "unable to CreateOrUpdate Service")
	}

	// CreateOrUpdate DEPLOYMENT
	var app appsv1.Deployment
	app.Name = customResource.Name + "-app"
	app.Namespace = customResource.Namespace
	_, err = ctrl.CreateOrUpdate(ctx, r, &app, func() error {
		ModifyDeployment(customResource, &app)
		return controllerutil.SetControllerReference(&customResource, &app, r.Scheme)
	})
	if err != nil {
		return ctrl.Result{}, errors.Wrap(err, "unable to CreateOrUpdate Deployment")
	}

	return ctrl.Result{}, nil
}

func ModifyDeployment(cr myApi.CustomResource, deployment *appsv1.Deployment) {
	labels := generateLabels(cr.Name)
	if deployment.Labels == nil {
		deployment.Labels = make(map[string]string)
	}
	for k, v := range labels {
		deployment.Labels[k] = v
	}
	replicas := cr.Spec.Replicas
	deployment.Spec.Replicas = &replicas
	deployment.Spec.Template.Labels = labels

	templateSpec := &deployment.Spec.Template.Spec

	if len(templateSpec.Containers) == 0 {
		templateSpec.Containers = make([]corev1.Container, 1)
	}
	container := &templateSpec.Containers[0]

	container.Name = "myapp"
	container.Args = []string{"/opt/myapp/bin/myapp"}
	container.Image = "myrepo/myapp:v1.0"
	container.Resources = corev1.ResourceRequirements{
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    cr.Spec.CPU,
			corev1.ResourceMemory: cr.Spec.Memory,
		},
	}
}
```

# Up Next

In our [next post](/post/gp4k-kubebuilder-tdd/), we describe our journey of
figuring out how to apply Test Driven Development to a KubeBuilder controller.
