---
authors:
- jadekler
categories:
- Testing
- Go
- Agouti
- Chrome
- UI Testing
- UI
date: 2016-11-17T13:04:17-07:00
draft: false
short: |
  Acceptance tests for your UI are an excellent way to cover user functionality. Let's see how to write a simple
  acceptance test in Go with Agouti and have it run headlessly in a CI environment with Chrome.
title: Headless UI Testing with Go, Agouti, and Chrome
---

## Foreword

Acceptance tests are a fantastic way to ensure - from a user perspective - that your application works correctly. A
popular UI acceptance test library is [Agouti](https://github.com/sclevine/agouti). This post will detail how to
write a small Agouti acceptance test and run it in a containerized environment; one which mimics a CI environment.

In this blog post we'll be using the following:

- [Go](https://golang.org/) - testing language
- [Ginkgo](https://github.com/onsi/ginkgo) and [Gomega](https://github.com/onsi/gomega) - test framework and matchers
- [Agouti](https://github.com/sclevine/agouti) - our webdriver client and UI testing library
- [ChromeDriver](https://sites.google.com/a/chromium.org/chromedriver/) - webdriver
- [Xvfb](https://www.x.org/archive/X11R7.6/doc/man/man1/Xvfb.1.xhtml) - a virtual framebuffer X server to allow chrome
to run headlessly
- [concourse.ci](https://concourse.ci/) - CI server, whose tasks run on [Ubuntu](https://www.ubuntu.com/)
[Docker](https://www.docker.com/) containers

**Note:** All code is assumed to live at `$GOPATH/src/website` (feel free to change `website` to anything)

## Writing a simple web app

Let's create a simple `main.go`:

```go
package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("<html><body>Hello World</body></html>"))
	})
	fmt.Println("Starting on :8080")
	fmt.Println(http.ListenAndServe(":8080", nil))
}
```

We can now `go run main.go` and navigate to [localhost:8080](localhost:8080) and see our UI!

## Writing a simple test

First, let's get our dependencies:

```bash
go get github.com/onsi/ginkgo/ginkgo
go get github.com/onsi/gomega
go get github.com/sclevine/agouti
```

Then, let's set up our suite - `website_suite_test.go`:

```go
package main_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/onsi/gomega/gexec"
	"github.com/sclevine/agouti"
	"os"
	"os/exec"
	"testing"
)

var (
	agoutiDriver   *agouti.WebDriver
	websiteSession *gexec.Session
)

func TestWebsite(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Website Suite")
}

var _ = BeforeSuite(func() {
	agoutiDriver = agouti.ChromeDriver()
	Expect(agoutiDriver.Start()).To(Succeed())

	startWebsite()
})

var _ = AfterSuite(func() {
	Expect(agoutiDriver.Stop()).To(Succeed())
	websiteSession.Kill()
})

func getPage() *agouti.Page {
	var page *agouti.Page
	var err error
	if os.Getenv("TEST_ENV") == "CI" {
		page, err = agouti.NewPage(agoutiDriver.URL(),
			agouti.Desired(agouti.Capabilities{
				"chromeOptions": map[string][]string{
					"args": []string{
						// There is no GPU on our Ubuntu box!
						"disable-gpu",

						// Sandbox requires namespace permissions that we don't have on a container
						"no-sandbox",
					},
				},
			}),
		)
	} else {
		// Local machines can start chrome normally
		page, err = agoutiDriver.NewPage(agouti.Browser("chrome"))
	}
	Expect(err).NotTo(HaveOccurred())

	return page
}

func startWebsite() {
	command := exec.Command("go", "run", "main.go")
	Eventually(func() error {
		var err error
		websiteSession, err = gexec.Start(command, GinkgoWriter, GinkgoWriter)
		return err
	}).Should(Succeed())
}
```

And finally our test - `website_test.go`:

```go
package main_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	. "github.com/sclevine/agouti/matchers"
)

var _ = Describe("Website", func() {
	It("Displays hello world", func() {
		page := getPage()
		defer page.Destroy()

		Expect(page.Navigate("http://127.0.0.1:8080/")).To(Succeed())
		Eventually(page).Should(HaveURL("http://127.0.0.1:8080/"))
		Eventually(page.Find("body")).Should(HaveText("Hello World"))
	})
})
```

We'll need to make [ChromeDriver](https://sites.google.com/a/chromium.org/chromedriver/downloads) available on our `$PATH`
before we can run this on our local machine. Once that's done, run `ginkgo` to see this work.

## Setting up your CI environment

Concourse uses Docker containers to run tasks, so let's create a container that can run our test. Create the following
`Dockerfile`:

```
FROM ubuntu:14.04

ENV LANG="C.UTF-8"

# install utilities
RUN apt-get update
RUN apt-get -y install wget --fix-missing
RUN apt-get -y install xvfb --fix-missing # chrome will use this to run headlessly
RUN apt-get -y install unzip --fix-missing

# install go
RUN wget -O - 'https://storage.googleapis.com/golang/go1.7.linux-amd64.tar.gz' | tar xz -C /usr/local/
ENV PATH="$PATH:/usr/local/go/bin"

# install dbus - chromedriver needs this to talk to google-chrome
RUN apt-get -y install dbus --fix-missing
RUN apt-get -y install dbus-x11 --fix-missing
RUN ln -s /bin/dbus-daemon /usr/bin/dbus-daemon     # /etc/init.d/dbus has the wrong location
RUN ln -s /bin/dbus-uuidgen /usr/bin/dbus-uuidgen   # /etc/init.d/dbus has the wrong location

# install chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
RUN apt-get update
RUN apt-get -y install google-chrome-stable
RUN wget -N http://chromedriver.storage.googleapis.com/2.25/chromedriver_linux64.zip
RUN unzip chromedriver_linux64.zip
RUN chmod +x chromedriver
RUN mv -f chromedriver /usr/local/bin/chromedriver
```

Let's build our `Dockerfile`: `docker build . -t my-ci-container`

## Running your test headlessly

Let's now enter the container and run test scripts as if we were the concourse task:

1. First, enter the container with our app directory mounted:

    ```
    docker run -it -v $(echo $GOPATH/src/website):/gopath/src/website my-ci-container
    ```
1. Let's run the following in the container:

    ```
    export GOPATH=/gopath
    export PATH=$PATH:$GOPATH/bin
    go get github.com/onsi/ginkgo/ginkgo
    go get github.com/onsi/gomega
    go get github.com/sclevine/agouti
    service dbus restart
    cd $GOPATH/src/website
    xvfb-run TEST_ENV=CI ginkgo -v
    ```

## Conclusion

We've now created an acceptance test to test a very small server, and had it run locally in a docker container. This
blog post ends here, but in a real world environment you might use the `Dockerfile` we've created as the task image for
a [concourse.ci](concourse.ci) pipeline task, and use the commands that we ran manually as the pipeline task script.

## Debugging

Chances are, something will go wrong along the way. Here's what we've used to debug this stack:

### Flow

> test -> Agouti -> ChromeDriver -> google-chrome -> X server (via xvfb-run)

> test->Agouti: Tests use Agouti

> Agouti->ChromeDriver: Agouti talks to ChromeDriver over HTTP

> ChromeDriver->google-chrome: ChromeDriver spins up google-chrome instances for each 'session' (in Agouti this is NewPage)

> google-chrome->X server: The X server acts as the 'gui' for google-chrome. It can be started with `Xvfb` or by wrapping
the `chromedriver` call with `xvfb-run`

### Debugging ChromeDriver

ChromeDriver can manually be run with the `chromedriver` command. Helpful tips:

- `chromedriver --verbose` reveals a lot of info, including the command it runs `google-chrome` with!
- Agouti can spin up ChromeDriver itself with `agouti.ChromeDriver().Start()`
- Agouti can spin up ChromeDriver with `--verbose` by crafting your own `NewWebDriver` command (`.ChromeDriver()` is
a very light wrapper)
- You can spin up your own ChromeDriver (ex. `chromedriver --verbose`), and point Agouti at it with
`agouti.NewPage("http://127.0.0.1:9515", ...)` (9515 is the default port). The command `NewPage` is basically a
`curl -XPOST http://127.0.0.1:9515/session -d '{"desiredCapabilities": {}}'`

### Debugging google-chrome

Google-chrome can manually be run with the `google-chrome` command. Helpful tips:

- `curl -XPOST http://127.0.0.1:9515/session -d '{"desiredCapabilities": {}}'` to create your own session - this is
analagous to Agouti's `NewPage`. When run after a `chromedriver --verbose`, it will give you a bunch of useful info.
- Each `curl -XPOST http://127.0.0.1:9515/session -d '{"desiredCapabilities": {}}'` starts a `google-chrome` process. Each
of these processes is a page!
- Change how the `google-chrome` process is spun up by adding [capabilities](https://sites.google.com/a/chromium.org/chromedriver/capabilities).
For instance, you might want to have `chromedriver` spin up `google-chrome` processes with the `--disable-gpu` and
`--no-sandbox` options (see below)! This would be:

    ```
    curl -XPOST http://127.0.0.1:9515/session -d '{"desiredCapabilities": {"chromeOptions": {"args": ["disable-gpu", "no-sandbox"]}}}'
    ```

Here are some common errors that you might see if you were to try to run the `google-chrome` command:

---

```
Failed to move to new namespace: PID namespaces supported, Network namespace supported, but failed: errno = Operation
not permitted
Illegal instruction
```

`google-chrome` is trying to do sandbox-y things that a container won't let it do. Run with `--no-sandbox` option:
`google-chrome --no-sandbox`

---

```
root@6a59557360dd:/gopath/src/website# [1120/020402:ERROR:nacl_helper_linux.cc(311)] NaCl helper process running without
a sandbox!
Most likely you need to configure your SUID sandbox correctly

```

This cryptic error probably means that `google-chrome` is having trouble connecting to the X server. Run
`xvfb-run google-chrome --no-sandbox`, or
start X server manually (xvfb-run wraps this):

```
Xvfb :99 &
export DISPLAY=:99
google-chrome --no-sandbox
```

---

```
libGL error: failed to load driver: swrast
[1308:1332:1120/020823:ERROR:browser_gpu_channel_host_factory.cc(113)] Failed to launch GPU process.
```

This container has no GPU. Run with `--disable-gpu` option: `xvfb-run google-chrome --disable-gpu --no-sandbox`

---

```
[1141:1152:1120/020700:ERROR:bus.cc(434)] Failed to connect to the bus: Failed to connect to socket
/var/run/dbus/system_bus_socket: No such file or directory
```

The `dbus` service hasn't started. You can:

- Check status with `service --status-all`
- Restart dbus with `service dbus restart` (be sure to `service --status-all` after)
- Modify `/etc/init.d/dbus` with log statements and the like to further debug

---

```
Xlib:  extension "RANDR" missing on display ":99".
```

[You can ignore this error.](http://askubuntu.com/questions/754382/how-do-i-start-chromium-browser-in-headless-mode-extension-randr-missing-on-d)

