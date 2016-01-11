---
authors: 
- warren
categories:
- Firehose
- Loggregator
- CF CLI
- Logging & Metrics
date: 2015-10-20T20:54:48-06:00
short: |
  Get your Cloud Foundry Firehose logs and metrics straight to your fingertips.
title: Using the Cloud Foundry Firehose Plugin
---

## Firehose at your fingertips
On the Logging and Metrics team, we recently found ourselves in a need to debug the CF Firehose more easily and we wanted to share that tool with all CF operators out there. In case you don't know what the Firehose is, let me tell you: It is undoubtedly the most powerful feature added to the CF logging system in the last 2 years. That's why its typically also restricted to be used by just the admin users. You know the saying 'With great power comes great bragging rights" (or something like that).

### What is the firehose?
In all seriousness, the Firehose can be very useful. It is a stream of all application logs and all component metrics from the CF components. Unfortunately, so far it has been really difficult to access (you had to write some code in go to get access to that stream). But with our brand new Firehose CLI plugin, all you have to do is install the plugin from the plugin repository and you are good to go.

{{< responsive-figure src="/images/loggregator/diagram.gif" class="center">}}

### How can I obtain admin access?
As mentioned earlier, you need either admin access or some special permission to access the Firehose. Fortunately, the Loggregator [README](https://github.com/cloudfoundry/loggregator/#configuring-the-firehose) provides good details on how to set this up.

### How do I install the plugin?
Installing, the plugin is really simple.

1. Login to the CF CLI with your admin creds

    ~~~bash
    cf api <your_cf_api_url>
    cf login
    ~~~
1. Add the plugin repository

    ~~~bash
    cf add-plugin-repo CF-Community http://plugins.cloudfoundry.org/
    ~~~
1. Install the plugin

    ~~~bash
    cf install-plugin "Firehose Plugin" -r CF-Community
    ~~~

### How do I use the Firehose plugin?
There are two ways of using the plugin. There is an interactive mode and non-interactive mode.

The interactive mode requires some user input and will look something like below. You may select the type of messages you'd like to have streaming on your terminal by selecting an index. If you are curious as to why it doesn't start with 1, look [here](https://github.com/cloudfoundry/dropsonde-protocol/blob/master/events/envelope.proto#L13) and [here](https://github.com/cloudfoundry/firehose-plugin/blob/master/firehose/client.go#L85)

```no-language
$ cf nozzle
What type of firehose messages do you want to see?
Please enter one of the following choices:
    hit 'enter' for all messages
    2 for HttpStart
    3 for HttpStop
    4 for HttpStartStop
    5 for LogMessage
    6 for ValueMetric
    7 for CounterEvent
    8 for Error
    9 for ContainerMetric
  > 5
Starting the nozzle
Hit Ctrl+c to exit
```

You can also use the `--filter` flag to have the plugin operate without user interaction. For example, if you want to filter the log stream to contain just counter events then you can run the command like this `cf nozzle --filter CounterEvent`

If you want all logs and not automatically enter interactive mode, you can pass in the `--no-filter` flag. This is the same as hitting enter in the interactive mode.

### Share the load
So the Firehose has this nifty feature where the logs can be distributed across various sessions in order to reduce load. All you need to do is use the same subscription ID for each session. So what that means is, if you have two terminal windows open and you run the following command `cf nozzle --no-filter --subscription-id zaphod` the load would be split evenly among the two sessions. Although having two heads didn't seem to help Zaphod anyways.

### Don't Panic
In case you get any errors, just hold on to your towel.

| Error | Solution |
|----------------------------------------------------------------------------|----------------------------------------------------------|
| **Unauthorized error: You are not authorized. Error: Invalid authorization** | Just regenerate your auth-token like so: `cf oauth-token` |
| **Unable to recognize filter HtttpStarrrt** | Check your spelling |
| **Invalid filter choice** | Check your index choice. Enter a number from 2 through 9 |

### How we use this plugin?
We use `cf nozzle -n` primarily for debugging and acceptance purposes. It's a quick way to look for expected component and application logs. Recently, our PM used this tool to look for logs originating from the DEA after pushing an app to PCF. Before this tool, he would have had to

1. Setup his GOPATH and `go get` the [NOAA](https://github.com/cloudfoundry/noaa) library.
1. Set up the environment variables CF_ACCESS_TOKEN and DOPPLER_ADDR.
1. Follow instructions to build and run the firehose sample.
