---
authors:
- ascherbaum
categories:
- Concourse
date: 2018-10-05T13:18:37Z
draft: true
short: |
  How to use quoted and unquoted variables in Concourse CI templates
title: Quoted and unqouted template variables in Concourse CI
---

[Concourse CI](https://concourse-ci.org/) is a powerful testing tool, and it is highly flexible and configurable. The integrated template engine replaces [placeholders](https://en.wikipedia.org/wiki/Placeholder) (named "variables" in CI) with content from external input. This system allows to create a pipeline definitions without exposing credentials to any outsider, or it allows to store volatile data (like version numbers) in external files, close together.

A lesser known fact is that Concourse supports two different types of placeholders, quoted and unquoted.


# What is a placeholder?

A placeholder is a piece in the pipeline definition which is defined somewhere else. This can be a name, a version number, a password, a ssh key, basically anything. Often this is used to hide credentials from anyone who can see or modify the code for the pipeline. Only in the end, when the pipeline is loaded using "[fly set-pipeline](https://concourse-ci.org/setting-pipelines.html)", the placeholders are replaced with the real data.


### How to specify a placeholder

A variable, or placeholder, is specified using one of two different syntax:

- ((variable))
- {{variable))


### How to load variables

[fly](https://concourse-ci.org/fly.html) supports two commandline paratemers to specify variables:


- --var "key=value"
- --load-vars-from <filename>

Both parameters can be specified multiple times, values loaded later will overwrite values loaded earlier. All formats are loaded as [YAML](https://en.wikipedia.org/wiki/YAML), the files specified with "--load-vars-from" must contain valid YAML.


# Different types of placeholders

### Unquoted placeholders

The version which is most common today, and which is documented in the "set-pipeline" documentation, is using two opening and two closing parenthesis.

Pipeline example:

```
product-((version)).tar.gz
```

Let's assume the $version variable is "11", upon "flying" the pipeline this will be replaced to:


```
product-11.tar.gz
```


### Quoted placeholders:

The older version of placeholders, but still valid and working is quoted placeholders. They use two opening and two closing curly braces.

For the example above, quoted placeholders would surely not be useful, the final pipeline would look like this:

```
product-"11".tar.gz
```

Instead this can be used for places like when a variable is used as shell parameter, and the value might contain spaces or other problematic characters:


```
/usr/bin/transmit-message {{message-subject}} {{message-text}}
```

```
/usr/bin/transmit-message "Alert" "This is just a Test Message"
```




