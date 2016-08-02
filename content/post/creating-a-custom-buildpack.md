---
authors:
- ssmith
- geramirez
- jwen
- jchester
categories:
- Cloud Foundry
- Buildpacks
- Rust
- CF Runtime
date: 2016-08-02T11:44:11-04:00
draft: false
short: |
  This article will describe how to create a custom buildpack using Rust as an example language.
title: Creating a Custom Buildpack
---

## Overview

This article discusses how to create a custom buildpack using [Rust](https://www.rust-lang.org/en-US/) as an example language. First, we show how to create a simple buildpack that downloads Rust during staging. Then, we describe how to package Rust into the buildpack itself, so it is not downloaded during staging.

As a sample app, we use a simple `hello_world` Rust http server:

```
app
├── Cargo.toml
├── manifest.yml
└── src
    └── main.rs
```

The source code for this app can be found [here](https://github.com/jchesterpivotal/rust-buildpack/tree/master/cf_spec/fixtures/rust_app_hello_world_server).


### Part 1: A Minimal Viable Buildpack

At its core, a buildpack consists of three executable scripts in a `bin` directory:

```
  bin
  ├── compile
  ├── detect
  └── release
```

These scripts are usually written in Ruby or BASH and are executed in the order `detect`, `compile`, `release`.

#### detect
The `detect` script is run to [determine which buildpack](https://docs.cloudfoundry.org/buildpacks/detection.html) to use for app staging and takes one argument: the application's top level directory (or build directory). If the script exits successfully (i.e. exit code of zero), the buildpack will be used. Otherwise, the `detect` script for the next available buildpack will run.

To determine whether to return the success `detect` will usually look for evidence of the application's language. Since [`cargo`](http://doc.crates.io/guide.html) is the canonical package manager for Rust, we can just look for the `Cargo.toml` file, resulting in the simple script:

~~~ruby
#!/usr/bin/env ruby
# bin/detect <build-dir>

build_dir=ARGV[0]

if File.exist?(File.join(build_dir,'Cargo.toml'))
  puts 'Rust'
else
  exit 1
end
~~~

#### compile
The `compile` script is usually the most complicated of the three. It is responsible for taking the application source that's been uploaded and turning it into a runnable application. This may require installation of dependencies or compilation of source code, depending on the langauge and buildpack.

The script takes three arguments: the build directory, a cache directory, and an environment directory. For the purposes of this article, we will only consider the first. Our script starts by saving the arguments into variables:

~~~bash
#!/usr/bin/env bash
# usage: bin/compile <build-dir> <cache-dir> <env-dir>

set -o errexit
set -o pipefail

mkdir -p "$1" "$2"
build=$(cd "$1/" && pwd)
cache=$(cd "$2/" && pwd)
env_dir=$3
buildpack=$(cd "$(dirname $0)/.." && pwd)
~~~

The next step is to install the Rust compiler `rustc` and package manager `cargo` so we can compile our application. Rust provides an install script which can be downloaded and run:

~~~bash
# Install Rust
echo "-----> Installing latest stable Rust from rustup"
rust_installation_url="https://sh.rustup.rs"
curl -sSf $rust_installation_url | sh -s -- -y --default-toolchain stable 2>&1
export PATH=$HOME/.cargo/bin/:$PATH
~~~

With the compiler and package manager installed, building the app is straightforward:

~~~bash
# Compile Rust program
echo "-----> Running 'cargo build'"
cd $build
cargo build --release 2>&1
~~~

This will place the compiled Rust program `hello_world` into the `$build/target/release/` directory.

Note that once staging is complete, everything under the `$build` directory will be zipped up into the droplet and hence present in the application container at runtime. Since this is a different container from staging, we will have to give it a script which provides any necessary environment variables. This is done by creating a script underneath [`$build/profile.d`](https://docs.cloudfoundry.org/devguide/deploy-apps/deploy-app.html#profile) -- everything in this directory is run in the application container before starting.

So we finish our `compile` script:
~~~bash
# Ensure compiled Rust program is in runtime environment PATH
mkdir -p $build_dir/.profile.d
echo 'export PATH=$PATH:/app/target/release:/app/usr/local/bin' > $build_dir/.profile.d/rust.sh
~~~

#### release
The final script is the `release` script. It writes a YAML-formatted string containing the [default command](https://docs.cloudfoundry.org/devguide/deploy-apps/app-startup.html) used to start the application to `stdout`. It takes one argument, the build directory.

Since we've installed `cargo` into the build directory, it is available at runtime, and so `cargo run` can be used to start the application. It's easy to manipulate YAML in Ruby, resulting in the script:

~~~ruby
#!/usr/bin/env ruby
# bin/release <build-dir>

require 'yaml'

release_run_command = {}
release_run_command['default_process_types'] = {'web' =>'cargo run'}
puts release_run_command.to_yaml
~~~

#### Using the buildpack

To use our new buildpack, we need to zip it up and upload it to Cloud Foundry. This is done as follows:

```shell
$ pwd
/Users/pivotal/workspace/rust-buildpack

$ zip -r rust-buildpack-v0.0.1.zip ./bin

$ cf create-buildpack rust-buildpack rust_buildpack-v0.0.1.zip 1
Creating buildpack rust-buildpack...
OK

Uploading buildpack rust-buildpack...
Done uploading
OK
```

At this point, the buildpack is ready and will detect a Rust application pushed with `cf push`. The completed example can be found at this [release](https://github.com/jchesterpivotal/rust-buildpack/releases/tag/minimum-viable-uncached-buildpack).

### Part 2: A Cached Buildpack

While the above buildpack is straightforward, it requires that Rust toolchain be installed from the internet every time an app is staged. This might not always be desired. In the next section, we will describe how to package these dependencies into the buildpack itself and install them during staging as part of the `compile` step.

To do so, we will use a Ruby gem, [buildpack-packager](https://github.com/cloudfoundry/buildpack-packager). This gem will read a file called `manifest.yml` and use it to create the buildpack `.zip` file.

#### Building the Rust toolchain

In order to package `rustc`, `cargo` and the required libraries in our buildpack, we first must build them. We will do this using the same docker image, [`cloudfoundry/cflinuxfs2`](https://hub.docker.com/r/cloudfoundry/cflinuxfs2/) as is used for staging and runtime. Inside the container, running `curl -sSf https://static.rust-lang.org/rustup.sh | sh` will install the latest stable binaries for `rustc` and `cargo`.

The command `ldd $(which rustc)` shows us that a bunch of libraries that `rustc` depends on have been installed to `/usr/local/lib/`. For `rustc` to work, we must package these as well. This gives us the `tar` command:

```shell
tar -cvf rust-1.10.tgz $(which rustc) $(which cargo) /usr/local/lib/*.so /usr/local/lib/rustlib/
```

This `.tgz` file is ready to be transferred to the local filesystem.

#### Buildpack Manifest

Next, we use the `manifest.yml` file to describe the contents of the buildpack. This file is required to contain the contains the following objects:

* `language`. The language of the buildpack. Example:

```
---
language: rust
```

* `dependencies`. Contains a list of 5 objects, `name`, `version`, `uri`, `md5`, `cf_stacks`. Example:

```
dependencies:
  - name: rust
    version: 1.10.0
    uri: file:///Users/pivotal/workspace/rust-output/rust-1.10.0.tgz
    md5: 1460714f450f3f1d2ff2032acdcbb436
    cf_stacks:
      - cflinuxfs2
```

`name` and `version` are simply the name and version of the dependency. `md5` is the md5 checksum of the `.tgz` file we created. `uri` is a uri describing where to find the dependency. In our case, this is on the local filesystem, but this could also point to a remote address.

* `url_to_dependency_map`. Contains a list of 3 objects, `match`, `name`, and `version`. Example:

```
url_to_dependency_map:
  - match: rust-(\d+\.\d+\.\d+)
    name: rust
    version: $1
```

`match` contains a regex which can be used to map any uri to dependencies with a given name and version specified under `dependencies`. Note that `version` can be a capture group of that `match` regex. In this case, this mapping specification would map a uri like `https://static.rust-lang.org/dist/rustc-1.10.0-src.tar.gz` to a dependency with the name `rust` and the version `1.10.0`.

* `exclude_files`. A list of files to exclude. Example:

```
exclude_files:
- ".git/"
- ".gitignore"
- ".gitmodules"
- cf_spec/
- target/
- "*.zip"
```

By default, `buildpack-packager` will zip everything in the current directory into the buildpack. As suggested by the name, anything in this list will be excluded from the buildpack. Note that it accepts wildcards, e.g. `*.zip`

#### Changes to the buildpack scripts

The next step is to determine if any changes need to be made to the `detect`, `compile` and `release` scripts. The `detect` script doesn't depend on caching, so it remains the same. The `compile` and `release` scripts, require some modification.

In the `compile` script we first need to determine if the buildpack is cached or not. The convention is that a cached buildpack contains a `dependencies` directory. So:

~~~bash
if [ -d "$buildpack_dir/dependencies" ]; then
    # install from $buildpack_dir/dependencies
    echo "-----> Installing Rust from cached buildpack"
else
    # Install Rust from internet
    echo "-----> Installing latest stable Rust from rustup"
    rust_installation_url="https://sh.rustup.rs"
    $CURL -sSf $rust_installation_url | sh -s -- -y --default-toolchain stable 2>&1
fi
~~~

Note that in the uncached case, we can use our code from the previous example.

Inside this `if` block, we first need to locate the cached `rust-1.10.0.tgz` file in the `dependencies` directory. To do so we will use the [compile-extensions](https://github.com/cloudfoundry/compile-extensions) library (adding it as a submodule to the buildpack directory). This library provides a script, `./bin/translate_dependency_url`, which takes a `uri` as specified in the `manifest.yml` dependencies object, and returns a uri giving the location of the file inside the staging container.

Using this script, we can download `rust-1.10.0.tgz` into a temp directory and extract it:

~~~bash
    dependency_url="file:///Users/pivotal/workspace/rust-output/rust-1.10.0.tgz"
    local_rust_file_url=$($buildpack_dir/compile-extensions/bin/translate_dependency_url $dependency_url)

    tmp_dir="/tmp/rust_install"
    mkdir -p $tmp_dir

    pushd $tmp_dir
        rust_file="rust.tgz"
        curl $local_rust_file_url -o $rust_file
        tar -xvf $rust_file
        export PATH="$PWD/usr/local/bin:$PATH"
    popd
~~~

Note that we add the location of the `rustc` and `cargo` binaries to our path. Once these have been installed, we can build our application in the same way as before (i.e. with `cargo build --release`).

Because the Rust compiler outputs a single executable file (all Rust libraries it depends on are compiled and statically included), we could install the Rust toolchain to a temp directory. This means it is not included in the droplet + application runtime container, greatly reducing its size. This does require a slight change to the `release` script:

~~~ruby
#!/usr/bin/env ruby
# bin/release <build-dir>
require 'yaml'

build_dir = ARGV[0]

cargo_metadata = File.read("#{build_dir}/Cargo.lock").split("\n")

cargo_metadata[1].match(/name = \"(.*)\"/)
app_executable = $1

release_run_command = {}
release_run_command['default_process_types'] = {'web' => app_executable}
puts release_run_command.to_yaml
~~~

Specifically, this reads the `Cargo.lock` file (generated by `cargo build --release`) and extracts the name of the output executable from the second line. Since our `compile` script has ensured that this executable is in the runtime container's `$PATH`, we can use it as the start command. 

Strictly speaking, it would be more robust to use a `toml` parsing library/gem and extract the name that way. Making such a gem available to the `detect` script during staging is outside the scope of this article.

#### Using buildpack-packager

Now that we've created the `manifest.yml` file and updated our buildpack scripts, we are almost ready to use `buildpack-packager` and create the cached buildpack. The last required file is named `VERSION` and as expected contains the semver version of the buildpack. Example:

```
0.0.2
```

Because `buildpack-packager` is a gem, we can add it to a `Gemfile`:

~~~ruby
source 'https://rubygems.org'

ruby '2.3.1'
gem 'buildpack-packager', git: 'https://github.com/cloudfoundry/buildpack-packager', tag: 'v2.3.1'
~~~

and install it using `bundle install`. Our directory structure now looks like:

```
rust-buildpack
├── Gemfile
├── Gemfile.lock
├── README.md
├── VERSION
├── bin
│   ├── compile
│   ├── detect
│   └── release
├── compile-extensions
├── manifest.yml
```

At this point, we are finally able to create our cached buildpack:

```
$ pwd
/Users/pivotal/workspace/rust-buildpack

$ buildpack-packager --cached
Downloading rust version 1.10.0 from: file:///Users/pivotal/workspace/rust-output/rust-1.10.0.tgz
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  232M  100  232M    0     0   292M      0 --:--:-- --:--:-- --:--:--  279M
  Using rust version 1.10.0 with size 233M
  rust version 1.10.0 matches the manifest provided md5 checksum of 1460714f450f3f1d2ff2032acdcbb436

Cached buildpack created and saved as /Users/pivotal/workspace/rust-buildpack/rust_buildpack-cached-v0.0.2.zip with a size of 106M
```

This buildpack can be uploaded to Cloud Foundry as described in Part 1. Note that when this cached buildpack is used, it will still connect to the internet during the `cargo build --release` step. This is because `cargo` offers no way to vendor the Rust dependencies as documented [here](http://doc.crates.io/faq.html#how-can-cargo-work-offline). So creating a Rust buildpack that does not require internet access is not really possible at this point in the Rust tooling's lifecycle.

The completed example Rust buildpack that we've worked through can be found at this [repo](https://github.com/jchesterpivotal/rust-buildpack/).
