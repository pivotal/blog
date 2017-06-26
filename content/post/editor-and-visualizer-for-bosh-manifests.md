---
authors:
- jamil
categories:
- BOSH
- Editor
- Visualization
date: 2017-06-26T19:42:46-05:00
short: |
  BOSH Editor is in-browser application that facilitates the creation of BOSH manifests. It includes smart auto-complete features and a way to visualize different segments of the manifest on the fly.
title: "A Smart Editor and Visualizer for BOSH Manifests"
---

[BOSH](http://bosh.io/) is an open source tool for release engineering, deployment, lifecycle management, and monitoring of distributed systems.
BOSH can provision and deploy software over hundreds of VMs. It also performs failure recovery and software updates with zero-to-minimal downtime.

[BOSH Editor](http://bosh.jamilshamy.me/) is an in-browser application that facilitates the creation of BOSH manifests. It includes smart auto-complete features and a way to visualize different segments of the manifest on the fly. This project was built on top of [Swagger Editor](http://swagger.io/swagger-editor/), where it was modified to suit BOSH needs.

## Features

* Create BOSH manifests with ease, directly in your browser.
* Smart auto-complete features, including keywords and snippets.
* Visualize manifests in a graphical layout, makes it easy to understand concepts for beginners.
* Live rendering of the graphical representation as you type.
* Trace where BOSH variables are being used and how many times they are being referenced.
* Currently supports deployment manifests and runtime manifests.
* Built-in sample manifests.
* Easily configurable.
* Built on-top of [ACE Editor](https://ace.c9.io/) and [Swagger Editor](http://swagger.io/swagger-editor/); they do most of the heavy lifting.
* [Open for contribution](https://github.com/jamlo/bosh-editor).

## How It Works

Visit [http://bosh.jamilshamy.me/](http://bosh.jamilshamy.me/) and start typing ... that's it ;-)

---

### 1) Smart Auto-complete

{{< youtube bw-IKccDW30 >}}

---

### 2) Live Graphical Layout

{{< youtube XeUYB-SHfeQ >}}

---

### 3) Trace BOSH Variables Usage

{{< youtube 2I_1YN6I1Eg >}}

---

### 4) Built-in Sample Manifests

{{< youtube LR52baz6mP0 >}}

---

### 5) Easily Configurable

{{< youtube zE-4ewBt90w >}}

---

## Notes

Check the [Github repo](https://github.com/jamlo/bosh-editor)
