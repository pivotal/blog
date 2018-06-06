---
authors:
- ascherbaum
categories:
- git
- GitHub
- Concourse
date: 2018-06-01T17:16:22Z
draft: true
short: |
  How to use "tag_filter" in "git" resources in Concourse CI
title: How to use "tag_filter" in "git" resources in Concourse CI
---

[Concourse CI](https://concourse.ci/) offers many different resource types to fetch from and put files into all kind of different places. One of these types is the ["git" type](https://github.com/concourse/git-resource), which supports cloning [git](https://git-scm.com/) repositories, or uploading changes.

This blog post will show how this resource type can be used to fetch a specific git tag from the repository.


## What are git tags?

git not only knows about _branches_, which are commonly used to develop new features and later on merge them into the _main_ (or _master_) branch. It also knows _tags_, which is a way to specify a descriptive name for a single commit. This is typically used to name versions: every version pointer (tag) will point to a specific commit in the history. That is a very lightweight feature, because the commit is already in the history and the tag is just pointing to it. Not much additional overhead, compared to other [SCM](https://en.wikipedia.org/wiki/Source_control_management).

A list of all available tags in a repository can be extracted using the _tag_ command:

```
$ git tag
```

This command allows to use a filter, which understands patterns:

```
$ git tag -l "*5.8*"
```


## How must the Concourse CI resource be configured?

The resource in CI is specified with a _name_ and _type_, and in addition the _source_ section becomes an additional *tag_filter* option:

```
- name: my_repo
  type: git
  source:
    uri: https://git-server/repos/repo.git
    branch: master
    tag_filter: "release/5.8"
```

Easy, isn't it? As with the "git tag" command, a pattern can be used in *tag_filter*:


```
- name: my_repo
  type: git
  source:
    uri: https://git-server/repos/repo.git
    branch: master
    tag_filter: "*5.8*"
```


# Pitfalls

Commonly, CI resources are configured in a way that they only load the last _n_ commits:

```
  - get: my_repo
    params: {depth: 10}
```

In this case only the last 10 commits are loaded from the repository. The _depth_ option saves bandwidth and disk space. However this also might not load the commit where the tag is pointing to.

If the *tag_filter* option is used, at least so many commits need to be fetched that the commit where the tag is pointing to is included. A better way is to not use the _depth_ option in such a case, especially if many changes are committed in the repository.


