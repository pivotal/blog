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
- Test Driven Development
date: 2019-10-14T17:00:00Z
draft: true
short: |
  Lessons we learned while building a controller with KubeBuilder, and how we
  made our unit tests fast enough for test driving.
title: How we built a controller using KubeBuilder with Test Driven development, Part 2
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

In our [previous post](/post/gp4k-kubebuilder-lessons), we reviewed some of the
details we learned about what it takes to build a working controller with
KubeBuilder. In this post, we take you through our journey of applying Test
Driven development within the KubeBuilder framework.

## Testing

Our journey of testing our Kubebuilder operator has been a long, iterative
process. At the start of that process, we thought it would be best to utilize
and follow the patterns in the Kubebuilder scaffolding. However, as our project
matured and we added features and accompanying test coverage, we encountered
barriers to overcome. Initially, we struggled to know when our code under test
was done executing. Then, after writing simple happy path tests, we wanted to
test our handling of unexpected errors. Finally, faced with poor test
performance, we decided to abandon the Kubebuilder test scaffolding altogether.

### Using the KubeBuilder Scaffolding

When we started our testing efforts, we thought it would be prudent to use the
Kubebuilder test scaffolding. When generating a new controller, Kubebuilder
generates scaffolding to start the test environment (testenv), create a manager,
and add the reconciler to the manager so it will be able to receive requests.
The testenv runs a real, ephemeral Kubernetes api-server and etcd to store
state.

Because the controller manager watches for changes to the objects, caches
retrieved objects, and batches reconciliations, and because the object must
round-trip through the api-server before reaching the controller, it may take
time for Reconcile() to be called and for its effects to be observed. Our tests
were intermittently failing because of the unpredictability of the test system.
Therefore, we sought to find a solution for synchronizing our tests so we would
know when Reconcile() finished running before we made assertions about the
results.

We found [a testing pattern from KubeBuilder v1][kb-v1-controllersuitetest]
which we thought would help fix our flaky tests. In this pattern, you create a
function that wraps the original Reconcile with a test Reconciler that writes to
a channel when it finishes running. Our own version of this method that we
called ReconcilerSpy is provided here. Compared to the Kubebuilder version, it
adds the Result and error from the reconciliation to the channel.

[kb-v1-controllersuitetest]: https://github.com/kubernetes-sigs/kubebuilder/blob/v1.0.8/pkg/scaffold/controller/controllersuitetest.go

```go
func ReconcilerSpy(inner reconcile.Reconciler) (reconcile.Reconciler, chan Reconciliation) {
	requests := make(chan Reconciliation)
	fn := reconcile.Func(func(req reconcile.Request) (reconcile.Result, error) {
		result, err := inner.Reconcile(req)
		requests <- Reconciliation{
			request: req,
			result:  result,
			err:     err,
		}
		return result, err
	})
	return fn, requests
}
```

If you would like to utilize this pattern, provide the ReconcilerSpy to the
Manager instead of your bare Reconciler when you set up the test environment so
it will receive the reconciliations.

```go
testReconciler, testReconciliations := ReconcilerSpy(&MyReconciler{})
builder.ControllerManagedBy(mgr).
			For(&v1beta1.MyCustomResource{}).
			Complete(testReconciler)
```

Your unit tests can then wait for the channel to receive, which will tell you
when Reconcile has finished.

```go
Expect(k8sClient.Create(ctx, myCR)).To(Succeed())

var r Reconciliation
Eventually(testReconciliations, 5*time.Second).Should(Receive(&r))

//make assertions
```

We noted there have been [some issues](https://github.com/kubernetes-sigs/kubebuilder/issues/651)
reported related to using the ReconcilerSpy pattern. In our estimation, the
common issue that users encountered stems from mixing up unit and integration
tests. Keep in mind the goal is to test the Reconcile() function, not any
re-queueing behavior of the ControllerManager or other system component
functionality. For example, in order to test that a Reconcile() will be
re-queued, just verify the returned Result value.

It seems that since the pattern proved difficult to use properly, Kubebuilder
has removed the helper method, and as of yet there is currently no alternative
provided. When used judiciously, we found the benefits of the ReconcilerSpy
pattern outweigh the possible issues.

### Using `reactive.Client`

The provided testenv and our custom ReconcilerSpy allowed us to write happy path
test cases where we did not encounter errors, but it did not give us a good way
to simulate errors. The
[recommendation we found from the Kubebuilder community][kb-issue-920]
was to set up the environment to actually produce the desired error. For
example, Create() the object beforehand in order to cause an error stating that
the object already exists when an attempt is made to Create() it again. However,
we found attempting to generate errors in a real environment can be tricky and
unreliable.

[kb-issue-920]: https://github.com/kubernetes-sigs/kubebuilder/issues/920

Testing that our code correctly handles unanticipated errors proved impossible
when dealing with a real client and api-server. For example, in order to test
that an error returned from Get() is handled, we must simulate the error
condition. Specifically, consider Get()-ing the object to be reconciled. When
using a real api-server, then we must Create() the object in the test case in
order for Reconcile() to be called. The only way to force Get() to fail that we
could think of was for the object to actually not exist. Therefore a
contradiction is created in which the object must both exist (for the code under
test to run), and not exist (for the error condition). We were unable to use the
provided framework to simulate this error case—we needed some way to inject
errors.

Test Driven Development benefits from having easy and reliable ways to inject
errors into injected dependencies so we can verify our code can react to
anything. Before using KubeBuilder, we had previously written a Controller using
the Operator SDK framework. That framework uses the [client-go] api, while
KubeBuilder uses [controller-runtime]. One feature that we had used extensively
and missed from client-go's fake client was its Reactors. Reactors intercept an
action made on the Client and create different behavior from what would normally
happen, so they are a great fit for injecting failures. For example:

[client-go]: https://github.com/kubernetes/client-go
[controller-runtime]: https://github.com/kubernetes-sigs/controller-runtime

```go
When("getting the customResource fails", func() {
	BeforeEach(func() {
		reactiveClient.PrependReactor("get", "mycustomresource", func(action testing.Action) (bool, runtime.Object, error) {
			return true, nil, errors.New("injected error")
		})
	})
	It("returns and logs the error", func() {
		Expect(reactiveClient.Create(ctx, myCR)).To(Succeed())
		Eventually(testReconciliations, 5*time.Second).Should(Receive(&r))
		Expect(r.err).To(MatchError("unable to fetch MyCustomResource: injected error"))
	})
})
```

In order to inject errors for testing our Kubebuilder operator, we developed our
own reactive client that wraps the provided controller-runtime Client and adds
reactors. `reactive.Client` embeds a `testing.Fake` (the same one used in
client-go’s FakeClient) which is used for managing and triggering the Reactors.

Like the client-go FakeClient, we provided a default reactor. Our default
reactor, instead of using an object tracker to store and retrieve objects,
delegates storage to the wrapped Client. Delegating to another Client meant we
could start using reactors with a real client talking to the api-server, and
later on change the delegate to a controller-runtime fake Client (see below).

The challenges creating `reactive.Client` surrounded adapting the reactor
actions developed for the client-go Client to the controller-runtime Client. The
client-go fake client is generated, and can provide specific concrete
runtime.Object implementations. The controller-runtime Client eschews generated
code, and so uses the more generic interfaces. Converting between these two
styles of API took some deep searching through parts of the Kubernetes API we
had not explored previously.

### Taking our tests from 20+ seconds to <1 second

<!--
Performance
Why we had a hard time with test case concurrency/parallelism:
Single apiserver
Tests create the same objects
Deleting test-created resources
Deleting owned resources
How our tests went from 20+ seconds to <<1 second
-->

At this point, we felt we had figured out testing with “the KubeBuilder way”
augmented with `reactive.Client`, but we weren’t satisfied with it. The tests
for our older controller that used the client-go fake package ran blazingly fast
(85 test cases in under ¼ second) while our KubeBuilder tests took multiple
seconds per test case. When doing TDD we run our tests very frequently (make a
small change, run tests), so when multiplied by the total number of tests, that
time difference caused us a lot of pain.

Our first attempt to run tests faster was to try to run the test cases in
parallel. We could not simply enable parallelism with the ginkgo test runner
since the tests share resources. We considered two techniques to isolate the
resources and enable parallelism: we could uniquely name our test objects on the
same testenv, or run multiple testenvs. If our tests all ran on the same
testenv/api-server, we would need unique names for every test object in order to
prevent conflicts. It would be easy to accidentally cause difficult-to-debug and
intermittently failing tests by naming an object the same as another test’s
object. To avoid this issue, we could instantiate a testenv for every test case.
In order to run multiple testenvs, we would need to instantiate and wrangle
multiple controller managers and associated `ReconcilerSpy`s and
`reactive.Clients`. The more we thought about the complexity involved in such a
test system, we missed the simplicity of our Operator SDK tests. Even with
parallelism, each test case still would take about 5 seconds to run, well above
our sub-second ideal. In addition, we started to question the value of using a
real api-server.

We wanted to get away from using the heavier testenv and instead strip things
down to use a fake client and call Reconcile() directly. Since `reactive.Client`
wraps an existing client, it was pretty easy for us to substitute in the fake
client from controller-runtime rather than the real client connected to the
testenv.

At this point we were able to call Reconcile directly which and achieve
sub-second test runs.

Before
```go
Expect(k8sClient.Create(ctx, pxf)).To(Succeed())
Eventually(pxfReconciliations, 5*time.Second).Should(Receive(&r))
Expect(r.err).NotTo(HaveOccurred())

// make assertions
```

After
```go
Expect(reactiveClient.Create(ctx, pxf)).To(Succeed())
_, err := pxfReconciler.Reconcile(pxfRequest)
Expect(err).NotTo(HaveOccurred())

//make assertions
```
