---
title: Intro to the Patch Command
authors:
- forde
categories:
- Patch
- Golang
short: |
  Quick intro on how to use the patch command to edit, and revert, the text of multiple files.
date: 2016-01-05T13:55:53-07:00
---

## Intro to the Patch Command
Long ago, the patch tool was created to apply diffs of code to codebases. This way when a developer submitted the diff for their new code, someone could assess and then apply the changes to the primary codebase.

These days, we have version control systems like git and svn to take care of logging and traversing all the code changes submitted.

So what about the patch command, does it still have a purpose?

## Why
The use case we had was that we needed to put a piece of software that was running on a server into a “debug” mode. The problem was there wasn’t debug mode implemented into its source code. To implement a feature like this would take months and we didn’t have control over the source code for the product.

The patch command is great for appyling and reverting changes to any text because is uses diffs. This means we can manipulate files whatever way we want, and then return return those files to their original state at the end of our cycle.

## Sample Use Case

Here is a simple Go app.

```go
$ cat src/code.go

package main

import (
	"fmt"
)

func main() {
	validate()
	deploy()
	smokeTests()
}

func validate() {
	fmt.Println("Validating...")
}

func deploy() {
	fmt.Println("Deploying...")
}

func smokeTests() {
	fmt.Println("Running Smoke Tests...")
}
```

For the sake of this example, let's say that we're dependant on this app it's has to run before I can test my code. When we run it, it's doing two operations that we might want to remove to speed things up.

```
$ go run src/code.go

Validating...
Deploying...
Running Smoke Tests...
```

In our case, we ran a cycle in our test environments with this code to verify that `validate()` and `smokeTests()` pass successfully. Then we wanted to trim down our testing cycles so the goal was to remove this functionality for quicker feedback.

### Creating a Patch file

First, we'll make a copy of the code and make the changes that we want.

```go
$ cat src_altered/code.go

package main

import (
	"fmt"
)

func main() {
  //validate() **Disabled**
  deploy()
  //smokeTests() **Disabled**
}

func validate() {
	fmt.Println("Validating...")
}

func deploy() {
	fmt.Println("Deploying...")
}

func smokeTests() {
	fmt.Println("Running Smoke Tests...")
}
```

Then we'll get the diff which will serve as our patch file.

```
$ diff -ru src src_altered > code.patch; cat code.patch

diff -ru src/code.go src_altered/code.go
--- src/code.go	2015-11-25 17:55:17.000000000 -0500
+++ src_altered/code.go	2015-11-25 17:48:11.000000000 -0500
@@ -5,9 +5,9 @@
 )
 
 func main() {
-	validate()
+	//validate() **Disabled**
 	deploy()
-	smokeTests()
+	//smokeTests() **Disabled**
 }
 
 func validate() {
 ```

### Applying a Patch

Run the patch command with your new patch file as your input (-i). You
can also add the -b flag if you want a backup of the original file.

```
$ patch -p0 -i code.patch

patching file src/code.go
```

The -p flag is required, which specifies how many prefixed path
segements you want to remove from the path.

```go
$ cat src/code.go

package main

import (
	"fmt"
)

func main() {
	//validate()
	deploy()
	//smokeTests()
}

func validate() {
	fmt.Println("Validating...")
}

func deploy() {
	fmt.Println("Deploying...")
}

func smokeTests() {
	fmt.Println("Running Smoke Tests...")
}
```

### Reverting a Patch

For when we want to put the file to a clean state.

```
$ patch -p0 -Ri code.patch

patching file src/code.go
```

The only change is that we've told patch that we want to reverse (-R).

```go
$ cat src/code.go

package main

import (
	"fmt"
)

func main() {
	validate()
	deploy()
	smokeTests()
}

func validate() {
	fmt.Println("Validating...")
}

func deploy() {
	fmt.Println("Deploying...")
}

func smokeTests() {
	fmt.Println("Running Smoke Tests...")
}
```

### Patching Fail-Safes

Patch works off of diffs so it can figure out if you're trying to patch
or reverse a file twice so that you don't end up in an unrecoverable
state.

``` bash
$ patch -p0 -i code.patch

patching file src/code.go

$ patch -p0 -i code.patch

patching file src/code.go
Reversed (or previously applied) patch detected!  Assume -R? [n] n
Apply anyway? [n] n
Skipping patch.
1 out of 1 hunk ignored -- saving rejects to file src/code.go.rej

$ patch -p0 -Ri code.patch

patching file src/code.go

$ patch -p0 -Ri code.patch

patching file src/code.go
Unreversed patch detected!  Ignore -R? [n] n
Apply anyway? [n] n
Skipping patch.
1 out of 1 hunk ignored -- saving rejects to file src/code.go.rej
```

It also saves a .rej file whenever something goes wrong with any
operation so you can investigate.

### More & Thanks

As you can imagine, there is much more to the patch command. There isn't a lot of material out there but I would, as always, start with [the man page](http://www.freebsd.org/cgi/man.cgi?patch).

I never would have known this command existed if it weren't for [Aaron Jarecki](https://www.linkedin.com/profile/view?id=AAkAAAcAwNABp639qPfhGAX1KVuIkj5ghtUCJmc), so big shoutout goes to him.
