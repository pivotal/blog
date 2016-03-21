---
authors:
- flavorjones
categories:
- CF Runtime
date: 2016-03-20T17:00:00-04:00
short: >
  A useful C++ buildpack needs to consider header files and libraries,
  not just `make`. Here's a story about how I made a useful buildpack
  for a C++ web framework.
title: Making A Useful C++ Buildpack
---

__TL;DR:__

* running `make` is easy,
* but you need **header files** to compile against,
* and you need **libraries** to link against,
* and you probably want to **configure** your framework.
* hey! I've released [cloudfoundry-community/cppcms-buildpack](https://github.com/cloudfoundry-community/cppcms-buildpack)


## A Simple C/C++ Buildpack is Easy

If you want to run `make` during staging, that's pretty easy. Heroku
has a minimal buildpack,
[heroku-buildpack-c](https://github.com/heroku/heroku-buildpack-c),
that will simply run `configure` (if you've got a `configure` file)
and `make`. And it totally works on Cloud Foundry, you can go try it!


## Oh, wait.

You won't go try it out. I know you won't, because it's a terrible
idea.

It's totally impractical to write a web service in C++ without using
some sort of framework that would require header files and libraries
that aren't present in the rootfs.

How impractical? Here's a simple "Hello, world!" program that I found
by clicking on the first Google result that matched "c web server":

> https://github.com/fekberg/GoHttp

If you
[look at the code](https://github.com/fekberg/GoHttp/blob/master/GoHttp.c),
you'll see there's 500+ lines of C code that are simply handling GET
and HEAD requests for various mime types.

That seems pretty amazing; I actually expected it to be much bigger
and more complicated. Regardless, I would never, ever want to do that
myself, for a huge variety of reasons, primarily security, but also to
preserve my sanity and to make sure I was focusing on the
[right abstractions](http://engineering.pivotal.io/post/abstraction-or-the-gift-of-our-weak-brains/).

The hypothesis for the rest of this post it that **any robust web app
is going to be using a framework**, which will bring along its own
header files and libraries. And thus a buildpack that simply runs
`make` is not very useful.


## A Real-World Example

I was chatting with a business partner a few weeks ago about his
firm's need for a C++ buildpack. I'll call him "Bob." I brought up the
challenges of making sure header files and libraries are available
during staging.

"Wouldn't it be easier to pre-compile the binary on a development
system where all these files are available, and then deploy using the
[binary-buildpack](https://github.com/cloudfoundry/binary-buildpack)?"
I asked.

**"No, I want to preserve the simplicity of `cf push` for our C++
developers,"** Bob responded. "It's a great model, and there's no good reason it shouldn't work for our C++ microservice authors."

This absolutely blew my mind, as it turned on its head my mental model
of a C++ developer.

For many years I worked with productive C and C++ developers who all
preferred "manual transmission" tooling, to preserve developer
discretion and optimization in how code was built and deployed.

Now Bob, an internet-famous technology executive, was telling me that
he'd prefer "automatic transmission", as popularly described by
[Onsi's CF Haiku](https://twitter.com/onsijoe/status/598235841635360768):

> here is my source code
> <br>run it on the cloud for me
> <br>i do not care how

**ORLY!** Challenge accepted.


## CppCMS

Bob mentioned [CppCMS](http://cppcms.com/) as a potential C++ web
framework for microservice authors. I had never heard of it before,
and so step one was to get familiar with it, and deploy a "Hello,
World!" app.

The CppCMS site provides a "Hello, World!" app, and the code is pretty
tight (at least, compared to the
[GoHTTP](https://github.com/fekberg/GoHttp/blob/master/GoHttp.c)
implementation):

```c++
#include <cppcms/application.h>
#include <cppcms/applications_pool.h>
#include <cppcms/service.h>
#include <cppcms/http_response.h>
#include <iostream>

class hello : public cppcms::application {
public:
  hello(cppcms::service &srv) :
    cppcms::application(srv) {}
  virtual void main(std::string url);
};

void hello::main(std::string /*url*/)
{
  response().out() <<
    "<html>\n"
    "<body>\n"
    "  <h1>Hello World</h1>\n"
    "</body>\n"
    "</html>\n";
}

int main(int argc,char ** argv)
{
  try {
    cppcms::service srv(argc,argv);
    srv.applications_pool().
      mount(cppcms::applications_factory<hello>());
    srv.run();
  } catch(std::exception const &e) {
    std::cerr << e.what() << std::endl;
  }
}
```

The obvious challenge, however, being the compile-time requirement of
`cppcms` header files and the runtime requirement on both
`libcppcms.so` and `libbooster.so` shared object libraries.


## Let's Adopt Some Conventions

We can very easily reproduce some of
[heroku-buildpack-c](https://github.com/heroku/heroku-buildpack-c)'s
behavior, and demand that application authors provide a `Makefile` to
compile the application.

We might imagine a simple `Makefile` that assumes the existence of a `cppcms` directory containing header files and libraries:

```make
hello: hello.cpp
  c++ hello.cpp -o hello \
    -Lcppcms/lib -Icppcms/include \
    -lcppcms -lbooster -lz
```

But CppCMS also requires a
[JSON configuration file](http://cppcms.com/wikipp/en/page/cppcms_1x_config)
at runtime. Let's ask configuration authors to name this file as
`cppcms.js`, so we can:

1. know whether this is a CppCMS application (i.e., at `bin/detect` time)
2. inject configuration parameters into an application at runtime (e.g., `PORT`)

For context, here's what a typical development configuration looks like for CppCMS:

```json
{
  "service" : {
    "api" : "http",
    "port" : 8888
  },
  "logging" : {
    "level" : "debug"
  }
}
```

At detection time, let's look for `cppcms.js`:

```bash
# bin/detect
if [[ -f "$1/cppcms.js" ]] ; then
  echo "cppcms"
  exit 0
else
  echo "no"
  exit 1
fi
```

And at runtime, let's use `jq` to inject `IP` and `PORT`, and to make sure
the HTTP interface is active:

```bash
cp cppcms.js cppcms.js.template
cat cppcms.js.template | \
  jq ".service.port=${PORT}|.service.ip=\"0.0.0.0\"|.service.api=\"http\"" | \
  tee cppcms.js
```


## But What About the Headers and Libraries?

Making header files available at staging time seems pretty easy;
they're just text files, and can be simply copied from a CppCMS
distribution.

But shared-object libraries are harder. They need to be cross-compiled
for the rootfs. How can we make sure this happens safely?

Good news. The CF Buildpacks team has, over the last year,
open-sourced all the tooling that they use to generate binaries for
most of the Official Cloud Foundry™ buildpacks (binary, go, node, php,
python, ruby, and staticfile). One of these tools is
[binary-builder](https://github.com/cloudfoundry/binary-builder),
which cross-compiles binaries for the CF container rootfs.

I wrote a new "recipe" for CppCMS, which is on an
[experimental branch](https://github.com/cloudfoundry/binary-builder/tree/flavorjones-cppcms),
that downloads and verifies a checksum for a source tarball, then
configures and compiles it for the CF rootfs. It contains the header
files and the libraries (both static and shared), and so contains
everything we need to stage and run a CppCMS application.


## Putting It All Together

(The final version of the buildpack is at
[cloudfoundry/cppcms-buildpack](https://github.com/cloudfoundry-community/cppcms-buildpack).)

The pieces we need to assemble:

* the tarball containing the headers files and libraries
* a `bin/detect` script
* a `bin/compile` script
* a `bin/release` script
* a script to configure the application at runtime


### The CppCMS Tarball

The `binary-builder` job from the
[experimental branch](https://github.com/cloudfoundry/binary-builder/tree/flavorjones-cppcms)
creates a file, `cppcms-1.0.5-linux-x64.tgz`, containing header files
and both static and shared libraries.

We'll add this tarball to the buildpack as an archive which can be
used if and when the buildpack is used to compile an application; and
we'll make sure it's easily identifiable as having been cross-compiled
for
[`cflinuxfs2`](https://github.com/cloudfoundry/stacks/tree/master/cflinuxfs2)
(as opposed to another stack).


### `bin/detect`

Shown above; let's just look for the `cppcms.js` script.

If you're specifying your buildpack at `cf push` time (with the `-b`
parameter), this script won't even run, so it's not strictly necessary
unless you've added it to the admin buildpacks on your CF deployment.


### `bin/compile`

The workhorse of application staging, `bin/compile` must generate a
droplet that's deployable, and so has to do a few different things.

First, we'll untar the appropriate version of CppCMS for your stack into the application's directory (so it's in the eventual droplet):

```bash
CPPCMS_VERSION=1.0.5
TARBALL="${BUILDPACKS_DIR}/vendor/${CF_STACK}/cppcms-${CPPCMS_VERSION}-linux-x64.tgz"
if [[ ! -f $TARBALL ]] ; then
  ls ${BUILDPACKS_DIR}/vendor/${CF_STACK}
  error "could not find a cppcms libary for the '${CF_STACK}' stack."
fi
mkdir -p cppcms
tar -m --directory cppcms -zxf $TARBALL
```

Note that we make `CF_STACK` a first-class variable. If you've got
multiple stacks, you'll need to cross-compile CppCMS for each of them.


Then, we'll make sure it runs `configure` if you have an
autoconf-enabled application:

```bash
if [[ -f configure ]] ; then
  ./configure
fi
```

Next, we'll run `make`:

```bash
make
```

Finally, we'll set up a script to run at application startup to allow
us to inject runtime configuration (see next subsection).

```bash
mkdir -p ${BUILD_DIR}/.profile.d
cp ${BUILDPACKS_DIR}/bin/cppcms.sh ${BUILD_DIR}/.profile.d
```

(The final version of this script is viewable
[here](https://github.com/cloudfoundry-community/cppcms-buildpack/blob/master/bin/compile).)


### Configuring the Application at Runtime

Finally, we need to make sure that the application is configured
properly to run as a CF application. Primarily, this means listening
on the appropriate port, but also listening on the correct network
interface and making sure that HTTP is turned on (as opposed to
[FastCGI or some other craziness](http://cppcms.com/wikipp/en/page/cppcms_1x_tut_web_server_config)).

I showed above how we could do this using `jq`, which has been in the
rootfs since
[v1.2.0](https://github.com/cloudfoundry/stacks/releases/tag/1.2.0).

The other thing we'll need to do is to set the linker's path to be
able to find the libraries at runtime:

```bash
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:cppcms/lib
```

Following the existing
[buildpack convention](https://docs.cloudfoundry.org/devguide/deploy-apps/deploy-app.html#profiled),
we'll name this script after the buildpack, `cppcms.sh`, and put it
into the droplet's `.profile.d` directory (see above for where this is
done in the `bin/compile` script).


## Wrap It Up, Already.

Ok, ok. I've provided a "Hello, World!" application [within the
buildpack's repo](https://github.com/cloudfoundry-community/cppcms-buildpack/tree/master/test/fixtures/hello-world) that you can push with this command:

```bash
cf push my-app-name -b https://github.com/cloudfoundry-community/cppcms-buildpack
```

Here's what I see:

```text
$ cf push flavorjones-cppcms -b https://github.com/cloudfoundry-community/cppcms-buildpack
Creating app flavorjones-cppcms in org flavorjones / space buildpack-acceptance as mdalessio@pivotal.io...
OK

Using route flavorjones-cppcms.cfapps.io
Binding flavorjones-cppcms.cfapps.io to flavorjones-cppcms...
OK

Uploading flavorjones-cppcms...
Uploading app files from: /home/flavorjones/code/cf/Buildpacks/cppcms-buildpack/test/fixtures/hello-world
Uploading 1.9K, 3 files
Done uploading
OK

Starting app flavorjones-cppcms in org flavorjones / space buildpack-acceptance as mdalessio@pivotal.io...
Creating container
Successfully created container
Downloading app package...
Downloaded app package (1.2K)
Staging...
-----> compiling with make ...
       c++ hello.cpp -o hello -Lcppcms/lib -Icppcms/include -lcppcms -lbooster -lz
-----> setting up .profile.d ...
Exit status 0
Staging complete
Uploading droplet, build artifacts cache...
Uploading droplet...
Uploading build artifacts cache...
Uploaded build artifacts cache (108B)
Uploaded droplet (24.6M)
Uploading complete

1 of 1 instances running

App started


OK

App flavorjones-cppcms was started using this command `make run`

Showing health and status for app flavorjones-cppcms in org flavorjones / space buildpack-acceptance as mdalessio@pivotal.io...
OK

requested state: started
instances: 1/1
usage: 1G x 1 instances
urls: flavorjones-cppcms.cfapps.io
last uploaded: Sun Mar 20 20:12:50 UTC 2016
stack: unknown
buildpack: https://github.com/cloudfoundry-community/cppcms-buildpack

     state     since                    cpu    memory    disk      details
#0   running   2016-03-20 04:13:13 PM   0.0%   0 of 1G   0 of 1G
```

Then:

```text
$ curl flavorjones-cppcms.cfapps.io
<html>
<body>
  <h1>Hello World</h1>
</body>
</html>
```

Heavenly!


## What's Next?

{{< responsive-figure src="/images/making-a-useful-c++-buildpack/bjarne.jpg" class="right small" >}}

I'd love to hear what people think of this approach. Currently this buildpack implements shared-linking, and not static-linking, because of what I read on [this page](http://cppcms.com/wikipp/en/page/ref_embedded#Static.Linking).

I'd also love to hear your thoughts on whether there are better ways
to configure the app at startup time.

Go Forth and Prosper with C++!

