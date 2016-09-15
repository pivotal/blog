---
authors:
- cunnie
categories:
- BOSH
date: 2016-09-14T17:19:30-07:00
draft: true
short: |
  Authors of a BOSH Release may want to release a new version when the
  upstream application is updated. This blog post describes the process
  of updating a BOSH Release while avoiding common pitfalls.
title: Updating a BOSH Release
---

When [PowerDNS](https://www.powerdns.com/) released version 4.0.1 of their
authoritative nameserver, we rushed to update our [BOSH
Release](https://github.com/cloudfoundry-community/pdns-release) (which was at
version 4.0.0). We thought it would be a walk in the park, but instead it was an
[epic
fail](https://github.com/cloudfoundry-community/pdns-release/commit/9e71c74bbf232896fb1865b19568b7eb1dfa6fa7)
(a final release which couldn't be deployed because the blobs were broken).

In this blog post we describe the procedure we ultimately followed to
successfully create an updated BOSH final release of the PowerDNS nameserver,
highlighting some of the tricky and non-obvious steps.

## Updating a BOSH Release

### 0. Ensure We're Using the Latest Release Version

We clone our release's git repo:

```bash
cd ~/workspace
git clone git@github.com:cloudfoundry-community/pdns-release.git
```

Alternatively, if we've already cloned, we make sure we have the latest
version of our release's code:

```bash
cd ~/workspace/pdns-release
git checkout master # assuming 'master' is the default branch
git pull -r
```

### 1. Download the Application's Updated Source Code

We download version PowerDNS's 4.0.1 source code to our `Downloads/` folder:

```bash
curl -L https://downloads.powerdns.com/releases/pdns-4.0.1.tar.bz2 \
  -o ~/Downloads/pdns-4.0.1.tar.bz2
```

### 2. Update BOSH Release to use New version

We're lazy — we use a Perl one-liner to update our release to use the new
version:

```bash
find packages/pdns -type f -print0 |
  xargs -0 perl -pi -e 's/pdns-4.0.0/pdns-4.0.1/g'
```

We're careful — we use `git diff` to double-check the changes:

```bash
git diff
```

### 3. Blobs: Out with the Old, In with the new

We add our new blob.


```bash
bosh add-blob ~/Downloads/pdns-4.0.1.tar.bz2 pdns/pdns-4.0.1.tar.bz2
```

<div class="alert alert-info" role="alert">
Note that we're using an experimental CLI whose syntax is slightly different
<sup><a href="#golangcli" class="alert-link">[Golang CLI]</a></sup> from the standard Ruby CLI's.
</div>

<div class="alert alert-warning" role="alert"> Be careful if you're using the
standard Ruby CLI: the arguments have changed. Specifically, the last argument
must be `pdns` and not `pdns/pdns-4.0.1.tar.bz2` (the last argument is a
directory, not a filename) (this was one of the causes of our initial failure:
we added our blob incorrectly, and the resulting blob path was the grossly
incorrect `pdns/pdns-4.0.1.tar.bz2/pdns-4.0.1.tar.bz2`).

If you're using the Ruby CLI, the correct command would be `bosh add blob
~/Downloads/pdns-4.0.1.tar.bz2 pdns`.
</div>

<p />

We remove the old blob (4.0.0) by manually editing `blobs.yml`:

```bash
vim config/blobs.yml # delete `pdns-4.0.0.tar.bz2` stanza
 # we take this opportunity to fix a broken path in our previous release:
 # we change `boost_1_61_0.tar.bz2:` to `boost/boost_1_61_0.tar.bz2:`
```

### 4. Create Development Release and Deploy

We create our development release:

```bash
bosh create-release --force
```

In our case, we use [BOSH Lite](https://github.com/cloudfoundry/bosh-lite) to
deploy and test because BOSH Lite is wonderfully convenient; however, any BOSH
director will do. We assume the BOSH Lite Director is running and targeted:

```bash
bosh upload-release
```

We take advantage of our existing BOSH Lite manifest for our PowerDNS release,
making sure to recreate the deployment if it already exists:

```bash
bosh -d pdns deploy manifests/bosh-lite.yml --recreate
```

### 5. Test the Development Release

Our compile should work. If there are compilation issues, we resolve them and
redeploy.

We use a simple test to ensure our new PowerDNS release is functioning
properly — we look up the SOA record of the domain _example.com_. The
PowerDNS default configuration will return a different record than the
one returned by the Internet DNS servers:

```bash
dig +short SOA example.com @10.244.8.64
  ns1.example.com. ahu.example.com. 2008080300 1800 3600 604800 3600
```

### 6. Upload the Blobs

Copy the `private.yml` into place.

We upload the blob:

### 7. Create the Final Release

We assign the version number '4.0.1' to our BOSH release (in order to
track our upstream's version).

```bash
bosh create-release --final --tarball --version 4.0.1 --force
```

We copy the tarball to a safe place (we will delete it in a subsequent step).

### 8. Commit but do NOT Push

We do not push our commit yet — if we discover a mistake, we won't suffer the
embarrassment of reverting the commit, unlike last time.

```bash
git add -N .
git add -p
git commit -m 'PowerDNS release 4.0.1'
git tag v4.0.1
```

### 9. Clean the Release Directory

We `git clean` our release the directory — this will force the blobs to be
downloaded, and uncover any errors in the blob parentheses

```bash
git clean -xfd
```

### 10. Deploy and Test the Final Release

```bash
bosh upload-release
bosh -d pdns deploy manifests/bosh-lite.yml --recreate
dig +short SOA example.com @10.244.8.64
  ns1.example.com. ahu.example.com. 2008080300 1800 3600 604800 3600
```

### 11. Push the Final Release's Commits

```bash
git push
git push --tags
```

### 12. (Optional) Publish the Release on GitHub and Update README.md

Upload the tarball to create a new GitHub Release

## Footnotes

<a name="golangcli"><sup>[Golang CLI]</sup></a> We are using an experimental
Golang-based BOSH command line interface
([CLI](https://github.com/cloudfoundry/bosh-cli)), and the arguments are
slightly different than those of canonical Ruby-based [BOSH
CLI](https://github.com/cloudfoundry/bosh/tree/master/bosh_cli); however, the
arguments are similar enough to be readily adapted to the Ruby CLI (e.g. the
Golang CLI's `bosh upload-stemcell` equivalent to the Ruby CLI's `bosh upload
stemcell` (no dash)).

The new CLI also allows variable interpolation, with the value of the variables
to interpolate passed in via YAML file on the command line. This feature allows
the redaction of sensitive values (e.g. SSL keys) from the manifest. The format
is similar to Concourse's interpolation, except that interpolated values are
bracketed by double parentheses "((key))", whereas Concourse uses double curly
braces "{{key}}".

Similar to Concourse, the experimental BOSH CLI allows the YAML file containing
the secrets to be passed via the command line, e.g. `-l ~/secrets.yml` or
`-l <(lpass show --note secrets)`

The Golang CLI is in alpha and should not be used on production systems.
