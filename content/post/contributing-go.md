---
authors:
- warren
categories:
- Golang
- contributing
- OSS
date: 2018-09-10
draft: true
short: |
  How to start contributing to the Golang project with an example
title: Let's Contribute to Golang!
---

I want to share some particular insights I gained after attending the
Contribution Workshop at GopherCon 2018.

The purpose of this post is to allow you to be able to contribute to Golang as
easily as possible and to provide you with some helpful tips. These tips are
coalesced from multiple sources and my own troubleshooting.

We are going to cover Gerrit...but don't be disheartened. Interacting with
Gerrit has evolved into an effortless process using the available tooling.

## Agenda

1. [Step 0: Initial Setup](#step-0-initial-setup)
1. [Step 1: Getting the source code](#step-1-getting-the-source-code)
1. [Step 2: Contributing](#step-2-contributing)
1. [Step 3: Testing the Example](#step-3-testing-the-example)
1. [Step 4: Submit Your Contribution](#step-4-submit-your-contribution)

# Step 0: Initial Setup

So first let's get the obvious prerequisites out of the way.

### Go
  You will need to have `go` installed.

### Contributors License Agreement (CLA)
  You will need to have signed either an individual or corporate license
agreement. Remember to use the google account you intend to contribute with.
These are the links you need to care about:

  - [Individual license agreement](https://developers.google.com/open-source/cla/individual)
  - [Corporate license agreement](https://developers.google.com/open-source/cla/corporate)
  - [Manage your license agreements](https://cla.developers.google.com/clas)

### Git
  You will need to have git installed and configured with the email address
you intend to use for making contributions.
You will also need to configure git authentication with Google's Gerrit
servers.

1. Go to https://go.googlesource.com.
1. Click on _Generate Password_.
1. Run the script provided. This will configure Git to hold your unique
     authentication key. This key is paired with one that is generated and
stored on the server, analogous to how SSH keys work.


### Gerrit

Go to https://go-review.googlesource.com/login/ and sign in using the same
google account. Gerrit email needs to match the email used in your `git` config.

__Terminology:__

- A "change" refers to a  pull request in github.
- A `CL` is an abbreviation for “changelist” which is the same as "change".
- Gerrit uses the following codes to identify the stage of the CL.

> ```
-2: this shall not be merged
-1: I would prefer this is not merged as is
0: no score, can be applied to a regular ol’ comment
+1: looks good to me, but someone else must approve
+2: looks good to me, approved (“Go Approvers” only)
```
Every change needs +2 before it gets merged.


### go-contrib-init

`go-contrib-init` is handy-dandy tool created to make our lives easier when contributing to
Golang.

```
go get -u golang.org/x/tools/cmd/go-contrib-init
```
Ensure that the binary is available on the `$PATH`.

This tool will:

- Check your CLA is valid
- Check the repo’s remote origin to make sure that it is pointing to a Gerrit
  server like go.googlesource.com
- Install `git-codereview` tool
- Setup git aliases for git-codereview


# Step 1: Getting the source code

## Core
```
git clone https://go.googlesource.com/go $HOME/workspace/golang
cd $HOME/workspace/golang
go-contrib-init
# All good. Happy hacking!
```

## Subrepositories

This might require a little more understanding. If you'd like to contribute to
a [subrepository of golang](https://godoc.org/-/subrepo) like `crypto` or
`tools` you must...

```bash
go get golang.org/x/tools
cd $GOPATH/src/golang.org/x/tools
go-contrib-init -repo tools
# All good. Happy hacking!
# Remember to squash your revised commits and preserve the magic Change-Id lines.
# Next steps: https://golang.org/doc/contribute.html#commit_changes

# Interesting point here, the remote will already be the Gerrit server
git remote -v
# origin  https://go.googlesource.com/tools (fetch)
```

The important points to take note of are:

- Github is used as a mirror to go.googlesource.com (the Gerrit server). This means that,

> ```
golang.org/x/tools --> go.googlesource.com/tools --> github.com/golang/tools
```

- `go-contrib-init` will check the paths of the source code and the remote
  origin.


__More Info:__

  - [How to Contribute to
Go](https://docs.google.com/presentation/d/14TfQtrsnz1yvOrX3uRa7ebkbOI3aByUB6dvvFIMXQ-8/edit?usp=sharing)
presentation.
  - [Contribution Guide](https://golang.org/doc/contribute.html)


## Step 2: Contributing...
### Let's write an example

A good way to contribute is by looking for a function that
requires an example or even better, a simple typo!

However, check https://tip.golang.org before looking for any changes because
the example you may want to write may already have been written. This contains
the latest merged CLs and has the most up to date version of the docs.

Say I want to add an example to a function specified in the `fmt` package.
```
cd $HOME/workspace/golang/src/fmt
vim example_test.go
```
By convention all the examples are written in `example_test.go` files.

Check out the link below to see how to write an example, or just look at the
examples already there and mess around.

__More Info:__

- [How to write an example]( https://golang.org/pkg/testing/#hdr-Examples)

## Step 3: Testing the Example

Once you've written your example, you want to make sure that it runs and looks
good.

#### 1. Run the example test

If your example has some `// Output` defined, you want to make sure the output
is correct.
```
go test example_test.go
```

#### 2. Check to see how it looks
```
GOROOT=$HOME/workspace/golang godoc -http=:6060
```

Open your browser to http://localhost:6060 and navigate to the page that you
want to review.

#### 3. Last but not least...
Yes, run all the tests...just to be sure

```bash
cd $HOME/workspace/golang/src
./all.bash
```

## Step 4: Submit Your Contribution

Now this is the part you all have been waiting for...

1. Once you are satisfied, create a branch and add your changes.

    ```bash
    git checkout -b mybranch
    git add
    ```

1. Commit the change using [the following
   guidelines](https://golang.org/doc/contribute.html#commit_messages) for
commit messages. This is __important__!! Your CL will be asked to update the CL commit message  Ideally, you'd be referencing a pre-existing Github issue
with the `NeedsFix` label.

    ```bash
    git change
    # or
    git codereview change
    ```

1. Submit the patch

    ```bash
    git mail
    # or
    git codereview mail
    ```

1. If you'd like to make further changes just redo the steps above.

    ```bash
    git add .
    git change
    git mail
    ```
The Googlers said the convention is to submit a change with a single commit.
Gerrit will display the patches made.

1. Go [to your dashboard](https://go-review.googlesource.com/dashboard/self)
   and keep up with the CLs.


And that's pretty much it. There's a lot more reading on the topic but as
mentioned in the beginning, this post was intended for the fastest way to get
you setup and started.

Take a another look at these resources:

- [How to Contribute to
Go](https://docs.google.com/presentation/d/14TfQtrsnz1yvOrX3uRa7ebkbOI3aByUB6dvvFIMXQ-8/edit?usp=sharing)
presentation.
- [Contribution Guide](https://golang.org/doc/contribute.html)

