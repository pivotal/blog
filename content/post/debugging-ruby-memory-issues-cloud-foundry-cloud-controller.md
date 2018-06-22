---
authors:
- gerg
- downey
- selzoc
- esharma
categories:
- Cloud Foundry
- CF
- Cloud Controller
- Ruby
- Ruby Memory Management
date: 2018-06-22T20:01:53Z
draft: true
short: |
  How the Cloud Foundry CAPI team diagnosed Ruby memory usage issues in the Cloud Controller API
title: Diagnosing Ruby Memory Issues in Cloud Foundry's API Server
image: /images/debugging-ruby-memory-issues/ccng-memory-usage.png
---

{{< responsive-figure src="/images/debugging-ruby-memory-issues/ccng-memory-usage.png" class="center" alt="Grafana dashboard displaying abnormal Cloud Controller memory usage in a test environment" >}}


## Introduction

Debugging memory issues in software is a notoriously difficult problem. Thankfully, there are already [many](https://samsaffron.com/archive/2015/03/31/debugging-memory-leaks-in-ruby) [other](http://www.be9.io/2015/09/21/memory-leak/) [excellent](http://blog.skylight.io/hunting-for-leaks-in-ruby/) [blog posts](https://blog.codeship.com/debugging-a-memory-leak-on-heroku/) describing techniques for discovering and fixing memory usage issues for Ruby programs. Many of these posts assume, however, that their audience has direct access to the affect environment, and for our particular situation this was sadly not the case. In this post we will cover how we diagnosed and fixed excessive memory usage for a Ruby web server, all without directly interacting with it. Before we begin our story, some background.

## Background

Cloud Controller is the API server that [Cloud Foundry](https://www.cloudfoundry.org/application-runtime/) users rely on to view and interact with the rest of the system. For instance, whenever a developer uses the Cloud Foundry CLI to deploy their applications or view their applications' status in Apps Manager, they are ultimately making requests that are served by Cloud Controller. Cloud Controller is a Ruby application and is deployed in data centers throughout the world as part of Cloud Foundry.

Occasionally our end-users will use the platform in ways we might not have predicted, which results in unique and difficult-to-reproduce issues. For instance, several months back a customer reported that their Cloud Controller instances were consuming excessive amounts of system memory and restarting very frequently. By default, Cloud Controller servers are configured to restart themselves after sustained high memory usage -- but these situations are rare and unexpected. Something was clearly wrong.

{{< responsive-figure src="/images/debugging-ruby-memory-issues/ccng-memory-usage-close-up.png" class="center" alt="Sawtooth memory usage pattern showing frequent restarts of the Cloud Controller server" caption="Cloud Controller instance exhibiting abnormal memory usage" >}}

## Understanding the Problem

We did not see this restarting behavior in our own test environments, so reproducing the problem required a better understanding of the customer’s environment and API usage. We began by asking the customer about the size and shape of their data (e.g. number of running apps, spaces, apps per space, etc.) and proceeded to comb through thousands of lines of Cloud Controller logs to get a feel for what type of API requests were typically made in the environment. Unfortunately, this knowledge alone was not enough to reproduce the issue. We needed to get a better view into what was consuming the memory on their environment. We needed to get a Ruby heap dump!

## Collecting Ruby Heap Dumps

By default, Cloud Controller does not trace object allocations or dump its heap, so we needed to get a bit creative. Fortunately, we already had [code in place](https://github.com/cloudfoundry/cloud_controller_ng/blob/3a72dbc5288c0a27498740dc1b2abb1fc39eebe0/lib/cloud_controller/runner.rb#L106-L112) to dump basic diagnostics when the `"USR1"` signal is sent to the Cloud Controller process. Taking advantage of this, we constructed a patch for the customer that would extend this diagnostics dump to include the heap before and after a forced garbage collection. [This patch](https://github.com/cloudfoundry/cloud_controller_ng/wiki/How-To-Get-a-Ruby-Heap-Dumps-&-GC-Stats-from-CC) modified the code to look something like this:

<pre class="pre-scrollable"><code class="language-ruby">
...
require 'objspace'; ObjectSpace.trace_object_allocations_start

module VCAP::CloudController
  class Runner

    ...

    def trap_signals
      trap('USR1') do
        EM.add_timer(0) do

          # Take a heap dump and acquire garbage collector stats
          # prior to forcing garbage collection
          File.open('/tmp/heap_dump_before_gc', 'w') do |file|
            ObjectSpace.dump_all(output: file)
          end

          File.open('/tmp/gc_stat_before_gc', 'w') do |file|
            file.write(GC.stat)
          end

          # Force the garbage collector to run
          GC.start

          # Take a heap dump and acquire garbage collector stats
          # after forcing garbage collection
          File.open('/tmp/heap_dump_after_gc', 'w') do |file|
            ObjectSpace.dump_all(output: file)
          end

          File.open('/tmp/gc_stat_after_gc', 'w') do |file|
            file.write(GC.stat)
          end
        end
      end

      ...
    end
  end
end
</code></pre>

## Understanding Ruby Heap Dumps

A Heap dump shows all of the objects that exist in the Ruby heap when the dump is generated. These objects are tagged with useful information like when and where they were allocated and what objects have pointers to them. Time is divided into a series of "generations" -- the periods between when the garbage collector runs. These generations do not directly correspond to clock time, but do give a sense of when objects were created relative to other objects in memory.

There is a lot of raw data in heap dumps, but they are not very easy for humans to understand. To help reason about what objects are sticking around at the time of the heap dump, we used the gem [heapy](https://github.com/schneems/heapy). Heapy processes the heap dump and groups objects by creation generation, allocation location, and storage location. This makes it easy to see when and where the objects in the heap were allocated.

For a typical, healthy ruby program, one would expect most of the objects in the heap dump to be allocated either during the early or late generations. Objects from early generations are allocated when the program first starts and include core Ruby classes (remember Ruby classes are objects) or classes used by the web server across multiple requests. If there are many objects persisting from intermediate generations, this can be a sign that something is going wrong (long-lived requests, leaked objects, etc).

Our heaps looked similar to this:

<pre class="pre-scrollable"><code class="language-bash">
$ heapy read heap_dump_after_gc

Analyzing Heap
==============
Generation: nil object count: 254197, mem: 0.0 kb
Generation:  68 object count: 7926, mem: 759.7 kb
Generation:  69 object count: 18361, mem: 1675.5 kb
Generation:  70 object count: 11405, mem: 1111.1 kb
Generation:  71 object count: 18155, mem: 1746.8 kb
Generation:  72 object count: 22477, mem: 2233.9 kb
Generation:  73 object count: 7204, mem: 799.2 kb
Generation:  74 object count: 105, mem: 16.6 kb
Generation:  75 object count: 16, mem: 3.0 kb
Generation:  76 object count: 16, mem: 3.0 kb
Generation:  78 object count: 632, mem: 57.3 kb
Generation:  79 object count: 64, mem: 5.5 kb
Generation:  80 object count: 86, mem: 9.4 kb
Generation:  82 object count: 2, mem: 1.0 kb
Generation:  83 object count: 7, mem: 1.6 kb
Generation: 100 object count: 11, mem: 1.5 kb
Generation: 110 object count: 7, mem: 1.3 kb
Generation: 111 object count: 177, mem: 12.1 kb
Generation: 122 object count: 123945, mem: 14808.5 kb
Generation: 123 object count: 296334, mem: 35263.5 kb
Generation: 124 object count: 4642, mem: 541.2 kb
Generation: 125 object count: 1054384, mem: 124715.9 kb
Generation: 126 object count: 223217, mem: 26382.3 kb
Generation: 127 object count: 210804, mem: 24935.2 kb
Generation: 128 object count: 206935, mem: 24483.9 kb
Generation: 129 object count: 214749, mem: 25395.1 kb
Generation: 130 object count: 212934, mem: 25183.7 kb
Generation: 131 object count: 208953, mem: 24723.4 kb
Generation: 132 object count: 184287, mem: 21854.8 kb
Generation: 133 object count: 236486, mem: 27939.3 kb
Generation: 134 object count: 215207, mem: 25530.7 kb
Generation: 135 object count: 213531, mem: 25594.6 kb
Generation: 136 object count: 3165, mem: 369.0 kb
Generation: 137 object count: 211699, mem: 24685.6 kb
Generation: 138 object count: 183402, mem: 22093.9 kb
Generation: 140 object count: 4274, mem: 498.4 kb
Generation: 141 object count: 6579, mem: 767.3 kb
Generation: 142 object count: 205877, mem: 24000.8 kb
Generation: 143 object count: 190335, mem: 22847.1 kb
Generation: 144 object count: 237839, mem: 27819.6 kb
Generation: 145 object count: 206768, mem: 24738.0 kb
Generation: 146 object count: 219855, mem: 25724.8 kb
Generation: 147 object count: 430, mem: 54.6 kb
Generation: 148 object count: 204817, mem: 24488.9 kb
Generation: 149 object count: 211586, mem: 25541.3 kb
Generation: 150 object count: 223172, mem: 26184.3 kb
Generation: 151 object count: 36834, mem: 4310.1 kb

Heap total
==============
Generations (active): 47
Count: 6093888
Memory: 689914.7 kb
</code></pre>

Notice how generation 125, a middle generation, looks abnormally large in comparison to its neighbors. Using `heapy` we can dive in further and see where the objects using this memory were allocated.

<pre class="pre-scrollable"><code class="language-bash">
$ heapy read heap_dump_after_gc 125

Analyzing Heap (Generation: 125)
-------------------------------

allocated by memory (127709103) (in bytes)
==============================
  117387638  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/adapters/mysql2.rb:256
    8429080  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/base.rb:264
    1795040  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/dataset/actions.rb:1051
      35200  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/process_model_presenter.rb:13
      11520  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/associations.rb:2248
      10560  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/relations_presenter.rb:92
       5280  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/controllers/base/model_controller.rb:330
       4800  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/relations_presenter.rb:95
       3840  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/presenters/v2/base_presenter.rb:7
       3840  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/presenters/v2/base_presenter.rb:20
       3840  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/process_model_presenter.rb:39
       3840  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/plugins/serialization.rb:192
       3520  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:59
       1377  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:84
       1120  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/em/connection.rb:49
        800  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/lib/cloud_controller/diego/protocol/open_process_ports.rb:15
        800  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/models/runtime/helpers/package_state_calculator.rb:17
        800  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/models/runtime/process_model.rb:384
        800  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/yajl-ruby-1.3.1/lib/yajl.rb:37
        758  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:28
        687  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/yajl-ruby-1.3.1/lib/yajl.rb:73
        576  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:9
        480  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:19
        400  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:10
        240  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:50
        240  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:57
        232  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/utils.rb:558
        176  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:31
        160  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:136
        160  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:32
        154  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/response.rb:72
        128  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:70
         80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/response.rb:27
         80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/utils.rb:568
         80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/request.rb:108
         80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/eventmachine.rb:1062
         80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/backends/unix_server.rb:53
         80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:54
         80  /var/vcap/packages/ruby-2.4/lib/ruby/2.4.0/securerandom.rb:242
         80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/em/deferrable.rb:191
         80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/eventmachine.rb:1068
         80  /var/vcap/packages/ruby-2.4/lib/ruby/2.4.0/uri/common.rb:388
         71  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/urlmap.rb:58
         66  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/actionpack-4.2.9/lib/action_dispatch/http/filter_parameters.rb:72
         40  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sinatra-1.4.8/lib/sinatra/base.rb:1068
         40  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sinatra-1.4.8/lib/sinatra/base.rb:131

object count (1054384)
==============================
  843005  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/adapters/mysql2.rb:256
  210727  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/base.rb:264
     120  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/relations_presenter.rb:95
      80  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/relations_presenter.rb:92
      60  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/controllers/base/model_controller.rb:330
      60  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/associations.rb:2248
      40  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/dataset/actions.rb:1051
      33  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:84
      20  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/models/runtime/process_model.rb:384
      20  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/process_model_presenter.rb:39
      20  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/models/runtime/helpers/package_state_calculator.rb:17
      20  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/plugins/serialization.rb:192
      20  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/yajl-ruby-1.3.1/lib/yajl.rb:37
      20  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/presenters/v2/base_presenter.rb:20
      20  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/presenters/v2/base_presenter.rb:7
      20  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/process_model_presenter.rb:13
      20  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/lib/cloud_controller/diego/protocol/open_process_ports.rb:15
      12  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:19
      12  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:28
       4  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:50
       4  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:57
       4  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/em/connection.rb:49
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/em/deferrable.rb:191
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:31
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:10
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:9
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/response.rb:27
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:32
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:59
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:54
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:136
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:70
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/backends/unix_server.rb:53
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/eventmachine.rb:1062
       2  /var/vcap/packages/ruby-2.4/lib/ruby/2.4.0/securerandom.rb:242
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/utils.rb:568
       2  /var/vcap/packages/ruby-2.4/lib/ruby/2.4.0/uri/common.rb:388
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/utils.rb:558
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/yajl-ruby-1.3.1/lib/yajl.rb:73
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/eventmachine.rb:1068
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/response.rb:72
       1  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/request.rb:108
       1  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/actionpack-4.2.9/lib/action_dispatch/http/filter_parameters.rb:72
       1  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/urlmap.rb:58
       1  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sinatra-1.4.8/lib/sinatra/base.rb:131
       1  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sinatra-1.4.8/lib/sinatra/base.rb:1068

High Ref Counts
==============================

  632318  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/adapters/mysql2.rb:256
  210767  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/base.rb:264
  200040  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/dataset/actions.rb:1051
    1040  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/process_model_presenter.rb:13
     160  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/presenters/v2/base_presenter.rb:20
     126  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:59
      80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/associations.rb:2248
      80  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/presenters/v2/base_presenter.rb:7
      40  /var/vcap/data/packages/cloud_controller_ng/209f67766e63e646e7e60113c2224a64961756c9/cloud_controller_ng/app/presenters/v2/process_model_presenter.rb:39
      20  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/plugins/serialization.rb:192
      12  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/em/connection.rb:49
      12  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:9
      12  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/headers.rb:10
      10  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:50
       8  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:31
       6  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:70
       4  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/connection.rb:32
       4  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/response.rb:27
       4  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/rack-1.6.8/lib/rack/utils.rb:558
       3  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:84
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/eventmachine.rb:1068
       2  /var/vcap/packages/ruby-2.4/lib/ruby/2.4.0/securerandom.rb:242
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/eventmachine-1.0.9.1/lib/eventmachine.rb:1062
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:136
       2  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/thin-1.7.0/lib/thin/request.rb:57
       1  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sinatra-1.4.8/lib/sinatra/base.rb:131
       1  /var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sinatra-1.4.8/lib/sinatra/base.rb:1068
</code></pre>

## Sifting Through the Dump

With the help of our friend heapy, we were able to get a sense of where all of these objects were coming from. The allocation point for our leaked objects was where our ORM loads objects out of the database. Unfortunately most of what we do is load ORM models out of our database, so this was not immediately helpful. Since classes in Ruby are also objects, we were able to [write a script](https://github.com/cloudfoundry/capi-release/blob/b9bba0c47b7cc7c9ee466b2eba9fc7f069577029/scripts/heap-utils/count-uniq-objects-by-class) to count the number of instances of different classes in the heap dump.

```bash
421453 "0x5642f6a6fa88"
211200 "0x5642f6a8fe00"
210912 "0x5642f6a7e240"
210687 "0x5642f933aa80"
  70 "0x5642f6a7ffa0"
  20 "0x5642fbb3c920"
  20 "0x5642fb5bf2b8"
   2 "0x5642fab0caa0"
   2 "0x5642faaebf80"
   2 "0x5642fa9f18c8"
   2 "0x5642fa9c6b00"
   2 "0x5642fa8971a8"
   2 "0x5642f789add8"
   2 "0x5642f6f69020"
   2 "0x5642f6d036c8"
   2 "0x5642f6a6d0d0"
   2 "0x5642f6a6c888"
   1 "0x5642fbb3db68"
   1 "0x5642fa82c240"
```

Once we had frequencies of certain objects, we focused on one of the objects with an extremely high frequency, such as `0x5642f933aa80`. We needed to find out the class of this object, so we searched through the raw dump again using `ag` ([the Silver Searcher](https://github.com/ggreer/the_silver_searcher)).

```bash
$ ag --mmap 0x5642f933aa80 heap_dump_after_gc | grep '"type":"CLASS"'

232204:{"address":"0x5642f933aa58", "type":"CLASS", "class":"0x5642f9263328", "name":"Class", "references":["0x5642f925b678", "0x5642f933aa80", "0x5642f737e638"], "file":"/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/models/runtime/user.rb", "line":2, "generation":72, "memsize":504, "flags":{"wb_protected":true, "old":true, "uncollectible":true, "marked":true}}

232205:{"address":"0x5642f933aa80", "type":"CLASS", "class":"0x5642f933aa58", "name":"VCAP::CloudController::User", "references":["0x5642f92812d8" … "0x5642f930d670"], "file":"/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/models/runtime/user.rb", "line":2, "generation":72, "memsize":5864, "flags":{"wb_protected":true, "old":true, "uncollectible":true, "marked":true}}
```

Based on the output above, we saw that `0x5642f933aa80` corresponded to the `VCAP::CloudController::User` class object. We could now identify the object!

```bash
210687 "0x5642f933aa80" ----> VCAP::CloudController::User
```

## Tracing the Referenced Objects

Once we knew the identities of the most frequently occurring objects, we just needed to figure out where they were coming from. The relative quantities of different types of objects might be a clue: if the heap is full of a particular resource, maybe it is the list endpoint for that resource or another endpoint that we know loads it. This was not enough information in our case, so we looked at some instances of the leaked classes and traced up their memory addresses to see what objects were holding on to them so tightly.

Every time we searched for a given object address, we also found out its class using the same process as earlier. For example:

```bash
$ ag --mmap 'class":"0x5642f933aa80' heap_dump_after_gc | head

11617:{"address":"0x5642f6bc5ef0", "type":"OBJECT", "class":"0x5642f933aa80", "ivars":3, "references":["0x7fd083e28028"], "file":"/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/base.rb", "line":264, "method":"allocate", "generation":125, "memsize":40, "flags":{"wb_protected":true, "old":true, "uncollectible":true, "marked":true}}
```

Above we found that `0x5642f6bc5ef0` was the address of an instance of a frequently occurring class. Time to find where this instance was referenced:

```bash
$ ag --mmap 0x5642f6bc5ef0 heap_dump_after_gc | less

11617:{"address":"0x5642f6bc5ef0", "type":"OBJECT", "class":"0x5642f933aa80", "ivars":3, "references":["0x7fd083e28028"], "file":"/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/base.rb", "line":264, "method":"allocate", "generation":125, "memsize":40, "flags":{"wb_protected":true, "old":true, "uncollectible":true, "marked":true}}

2300469:{"address":"0x7fd08762f980", "type":"ARRAY", "class":"0x5642f6a7ffa0", "length":10002, "references":[“0x5642f6bc5ef0”, ...], "file":"/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/dataset/actions.rb", "line":1051, "method":"_all", "generation":125, "memsize":89712, "flags":{"wb_protected":true, "old":true, "uncollectible":true, "marked":true}}
```

In this example we saw that the `User` instance was a member of a large array, but we did not know what object owned that array. We continued this process by searching for the address of the array.

```bash
$ ag --mmap 0x7fd08762f980 heap_dump_after_gc | less

2300484:{"address":"0x7fd08762fbd8", "type":"HASH", "class":"0x5642f6a7e240", "size":1, "references":["0x7fd08762f980"], "file":"/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/associations.rb", "line":2248, "method":"associations", "generation":125, "memsize":192, "flags":{"wb_protected":true, "old":true, "uncollectible":true, "marked":true}}
```

Now we had found that our array was referenced by a hash, so we continued the process and found what object referenced this hash.

```bash
$ ag --mmap 0x7fd08762fbd8 heap_dump_after_gc | less

4376456:{"address":"0x7fd0e036d888", "type":"OBJECT", "class":"0x5642fae5e2d0", "ivars":3, "references":["0x7fd0e036d978", "0x7fd08762fbd8"], "file":"/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/vendor/bundle/ruby/2.4.0/gems/sequel-4.49.0/lib/sequel/model/base.rb", "line":264, "method":"allocate", "generation":122, "memsize":40, "flags":{"wb_protected":true, "old":true, "uncollectible":true, "marked":true}}
```

We had finally reached a new, hopefully more interesting object. As before, we ran the following to find out what its class was:

```bash
$ ag --mmap 0x5642fae5e2d0 heap_dump_after_gc |  grep '"type":"CLASS"'

371974:{"address":"0x5642fae5e2d0", "type":"CLASS", "class":"0x5642fae5e2a8", "name":"VCAP::CloudController::Space", "references":["0x5642fb1f9db8" ... "0x5642faeb0c38"], "file":"/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app/models/runtime/space.rb", "line":4, "generation":72, "memsize":7960, "flags":{"wb_protected":true, "old":true, "uncollectible":true, "marked":true}}
```

It was a `VCAP::CloudController::Space` class! This turned out to be the most interesting class we found while walking up the object graph, but we didn't know that at the time so we continued the process above until we reached the root reference (a `Thread` object).

Since we found this `VCAP::CloudController::Space`, however, we were able to start thinking about what endpoint would return a `Space` hash containing an array of `Users`.

## Resolution

After tracing the leaked objects all the way to the top, we found the `EventMachine` thread that holds on to all requests. Short of intentionally writing a bunch of objects to `Thread.current`, the only explanation to this was that the requests were still in progress. With an understanding of the shape of the data, we were able to identify the problem endpoint. This endpoint needed to see whether or not a `User` belonged to a `Space` so it searched through an array of in-memory `User` objects in Ruby, rather than executing a simple SQL query. Worse yet, the array of `User` objects was reloaded and searched through for each of the API user's applications. This meant that an individual with access to many applications would trigger the same expensive operation for each application.

We learned that the environment that was exhibiting this behavior was a "sandbox" environment that gave all developers access to all other applications. To compound the problem, the environment also had an API consumer that was polling and fetching the entire list of applications every 30 seconds. Once enough of these requests stacked up, the Cloud Controller was no longer able to serve requests and eventually hit its memory quota, triggering a restart. We replaced the offending line with an SQL query and everything recovered. Like any good bug, the issue came down to fixing a [few lines of code](https://github.com/cloudfoundry/cloud_controller_ng/commit/d4d757d3ef205690839e6bc0960e9825199edcc7).

## Takeaways

Over the course of our investigation, we came up with some takeaways that we believe would help any team trying to diagnose a Ruby memory leak:

* **Take advantage of the tools:** Heap dumps make sense to computers, but not to humans. Using tools like [heapy](https://github.com/schneems/heapy) allowed us to make sense of a heap dump even though we are not robots.
* **Do not ONLY test as admin:** One of the original reasons our initial investigation did not reproduce the problem was because we were using an admin account. The code path exhibiting the memory issue was only exercised by non-admin users.
* **Be careful of your ORM shielding you from object allocation:**  One of the strengths of using an ORM is that it shields you from having to know the specifics of which DB operations are occurring. In our case, it was not obvious whether a line of code was loading the entire contents of a table into memory and then filtering  vs. filtering with SQL and only loading the results. It is often worth taking a peek at the SQL statements generated by the ORM to see if they match your expectations.
* **Offload as much as you can to the DB:** A surefire way to avoid consuming memory in your application is to not load it in the first place. DBs are really good at filtering data before returning it to you!
* **Test extreme scenarios:** Even in our non-admin testing and other production environments, we had not seen the memory problem. It’s worth doing at least some spot tests where you ramp up the quantity of a specific resource and run your performance tests.
* **There IS an answer:** It’s easy to get discouraged over a long-running investigation so take heart!  You will figure it out eventually.
