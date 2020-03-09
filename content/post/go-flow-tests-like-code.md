---
authors:
- cunnie
categories:
- Golang
- TDD
- BDD
date: 2020-02-16T17:16:22Z
draft: false
short: |
  When writing Behavioral Driven Development (BDD) Golang unit tests, pattern
  the flow of the tests after the code; it will make the tests easier to
  understand, navigate, and maintain.
title: Flow Your Tests Like Your Code
---

My co-worker Belinda Liu turned to me and said, "I don't like these tests at all;
they're hard to follow, and I'm not sure what they're testing."

I looked at the tests that I had spent much of yesterday afternoon working on.
She was right: they _were_ hard to follow (even for me, who had written some of
them!).

How had we gotten here? Our code was straightforward, but our tests were
byzantine (excessively complicated). We identified two problems:

1. the tests didn't line up with the code
2. the tests were deeply nested, but the code wasn't.

#### 1. Lining Up the Tests with the Code

Belinda and I work on Cloud Foundry's command line interface
([CLI](https://docs.cloudfoundry.org/cf-cli/)), a Golang-based utility which
allows end users to interact with Cloud Foundry (e.g. to push an application).
We write our tests with [Ginkgo](https://onsi.github.io/ginkgo/), a BDD-style
Golang testing framework.

In this post we'll explore a typical subcommand, `stage`, and its corresponding
unit tests to determine how well the code lines up with our tests (hint: it
doesn't).

In the screenshot below, the code for the [stage
subcommand](https://github.com/cloudfoundry/cli/blob/98cc92d7772ba3afab4f32ef2f052af07b18a6df/command/v7/stage_command.go)
is on the left. On the right is a minimap of the subcommand's Ginkgo [test
code](https://github.com/cloudfoundry/cli/blob/98cc92d7772ba3afab4f32ef2f052af07b18a6df/command/v7/stage_command_test.go).
(we use a minimap rather than the complete Ginkgo code because, at 300+ lines,
the tests aren't easy to digest). The pink arrows show where a particular line
of code is tested.  We're off to a good start (the first error condition is the
first test), but we rapidly spiral into chaos. There seems to be no rhyme or
reason why a particular test appears in a particular spot.

This disorganization exacts a cost: the tests are hard to follow, and coverage
is difficult to determine.

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/74696957-28452180-51ae-11ea-8b52-f4e80b6b73bf.png"
class="center" caption="The code is to the left, and the tests are to the right.  Note that the tests are much too large (>300 lines) to fit in the image, so we use a minimap. The pink arrows indicate where in the test file that particular line of code is tested." >}}

After refactoring the test, the pink arrows are organized (see image below).

Keen-eyed viewers may notice that our code has grown (it has; we added a
feature, [_`stage` should not require a
package_](https://www.pivotaltracker.com/story/show/166688397)). Our test
refactor was opportunistic, a drive-by: we were in the codebase adding a
feature, and we took an extra quarter-hour to refactor/reorganize our tests.

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/74874353-acfe7f80-5315-11ea-97f7-d05ddebd46de.png"
class="center" caption="The code is to the left, and the tests are to the right.  Note that the tests are much too large (>300 lines) to fit in the image, so we use a minimap. The pink arrows indicate where in the test file that particular line of code is tested." >}}

Lack of code coverage is much easier to identify when the tests are patterned
after the code. In fact, while writing this post, I realized that we had no test
coverage for the `GetNewestReadyPackageForApplication()` error path.  Prior to
the refactor, it would have gone unnoticed.

#### 2. Un-Nesting the Tests

The tests were nested more deeply than the code, as we found out by running
`egrep "When\\(|It\\(|Describe\\(" command/v7/stage_command_test.go | sed
's/$/})/'`.

Below is the layout of our test code _before_ the refactor. Our code was only
one-level deep—our flow control statements, which were limited to `if`,
weren't nested. But our tests were as many as three levels deep:

```go
	When("checking target fails", func() {})
		It("displays the experimental warning", func() {})
		It("returns an error", func() {})
	When("the user is logged in", func() {})
		When("the logging does not error", func() {})
			When("the staging is successful", func() {})
				It("outputs the droplet GUID", func() {})
				It("stages the package", func() {})
				It("displays staging logs and their warnings", func() {})
			When("the staging returns an error", func() {})
				It("returns the error and displays warnings", func() {})
		When("the logging stream has errors", func() {})
			It("displays the errors and continues staging", func() {})
		When("the logging returns an error due to an API error", func() {})
			It("returns the error and displays warnings", func() {})
```

After the refactor, we see that our test code is now two levels deep. "Why not
one level deep?" you may ask. The answer is that the feature we were
implementing—the reason we were modifying our code—introduced a new level in our
code: it now had a nested `if` block. Our code now had two levels, which matches
the two levels of our test.

Our newly-refactored tests mirror our code, so much so that by looking at them
we get an intuitive sense of how our code was written:

```go
	When("checking target fails", func() {})
		It("displays the experimental warning", func() {})
		It("returns an error", func() {})
	When("the package's GUID is not passed in", func() {})
		It("grabs the most recent version", func() {})
		When("It can't get the application's information", func() {})
			It("returns an error", func() {})
	When("the logging stream has errors", func() {})
		It("displays the errors and continues staging", func() {})
	When("the logging returns an error due to an API error", func() {})
		It("returns the error and displays warnings", func() {})
	When("the staging returns an error", func() {})
		It("returns the error and displays warnings", func() {})
	It("outputs the droplet GUID", func() {})
	It("stages the package", func() {})
	It("displays staging logs and their warnings", func() {})
```



### Takeaways

- It's easier to navigate the tests when they're patterned after the code. Much
  easier.

- Refactoring the unit tests can be done opportunistically. Sure, one can choose
  to do a grand refactor of the entire suite of unit tests, but that's not
  always an option, and the ability to do these refactors piecemeal, when you're
  modifying the code in question, is a definite advantage.

- Refactoring a test is not time consuming, and can be done in as few as fifteen
  minutes.

### References

[_Code: Align the happy path to the left
edge_](https://medium.com/@matryer/line-of-sight-in-code-186dd7cdea88), Mat
Ryer, August, 2016

[_Practical Go: Real world advice for writing maintainable Go
programs_](https://dave.cheney.net/practical-go/presentations/qcon-china.html#_return_early_rather_than_nesting_deeply),
Section 4.3 _Return early rather than nesting deeply_, Dave Cheney, April, 2019

The title, _Flow Your Code Like Your Tests_, is an homage to Philip K. Dick's
novel, [_Flow My Tears, the Policeman
Said_](https://en.wikipedia.org/wiki/Flow_My_Tears,_the_Policeman_Said).  The
title is one of the few examples in the English language where the verb "flow"
is used in the [imperative mood](https://en.wikipedia.org/wiki/Imperative_mood).

### Acknowledgements

Belinda Liu: inspiration, suggestions & edits.
