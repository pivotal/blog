---
authors:
- dat
categories:
- Data Science
- Machine Learning
- Smart Apps
- TDD
- Continuous Integration
- Concourse
date: 2017-02-16T09:09:28+01:00
draft: false
short: |
  This article will show why continuous integration is also important for smart apps projects.
title: Continuous Integration for Data Science
---

This is a follow up post on [Test-Driven Development for Data Science](http://engineering.pivotal.io/post/test-driven-development-for-data-science/) and [API First for Data Science](http://engineering.pivotal.io/post/api-first-for-data-science/) focusing on Continuous Integration.

## Motivation

Last time we wrote about the importance of test-driven development for data science, especially in the context of what we call smart applications. There are many examples for smart applications, for example, Google’s Inbox has a feature that is called [Smart Reply](https://blog.google/products/gmail/computer-respond-to-this-email/) which uses machine learning to suggest three possible answers to your incoming messages.

{{< responsive-figure src="/images/continuous-integration-for-data-science/smart-reply.gif" class="center" >}}
<p align="center">
  Figure 1: Google’s Smart Reply feature. Photo source: [Techcrunch](https://techcrunch.com/2016/03/15/google-brings-its-nifty-smart-reply-feature-to-inbox-on-the-web/).
</p>

Another instance of a smart app is [Apple’s Photo app on the iPhone](http://www.apple.com/lae/ios/photos/). While taking a photo, it recognizes faces and places through machine learning and automatically relates them together so that searching for photos becomes much smarter.

{{< responsive-figure src="/images/continuous-integration-for-data-science/apple-photo-search.jpg" class="center" >}}
<p align="center">
  Figure 2: Apple’s smart photo search feature. Photo source: [Appleinsider](http://appleinsider.com/articles/16/09/22/inside-ios-10-examining-the-new-smart-photos-features).
</p>

Those apps have in common that they are powered with machine learning features and they are embedded in a piece of software which is continuously updated and delivered to consumers. A common problem is to integrate those parts in a shared team well, especially for a more complex product. In this article, we will discuss how we can use continuous integration (CI) to prevent such a problem with a specific focus on data science.

## The Problem

At Pivotal Labs, we also help our clients creating smart applications with a [balanced team](http://www.balancedteam.org/) concept. A balanced team for us consists of software engineers, designers, product managers and data scientists (see Figure 3). Together, we build products which are meaningful in an agile and iterative fashion which means that our piece of software is continuously updated and shipped to customers. So that customers can test it very early and give feedback which are then integrated.

{{< responsive-figure src="/images/continuous-integration-for-data-science/balanced-team.png" class="center" >}}
<p align="center">
  Figure 3: Balanced Team.
</p>

An important challenge there is that different team members work on different features at the same time. For example, one team consisting of software engineers and designers might work on the front-end application and another team of software engineers and data scientists might work on the smart feature. In the end the final goal is that every piece in the product should integrate well together.

> “Team programming isn’t a divide and conquer problem. It is a divide, conquer, and integrate problem. The integration step is unpredictable, but easily can take more time than the original programming. The longer you wait to integrate, the more it costs and the more unpredictable the cost becomes.” Kent Beck - Extreme Programming Explained

When it comes to the integration part, software engineers have been faced with this problem for a long time. They tend to work on a code base which is shared by many developers. The challenge they face there is that each individual or pairs work on a separate problem and then integrating the solution into the larger code base might be very difficult, especially the longer they wait.

## Continuous Integration

To mitigate the integration problem, software engineers came up with the concept of [continuous integration](https://en.wikipedia.org/wiki/Continuous_integration) or shortly CI. CI is a development practice that requires developers to integrate code into a shared repository multiple times a day. This code is then automatically tested so that teams can detect problems early.

{{< responsive-figure src="/images/continuous-integration-for-data-science/ci-cycle.png" class="center" >}}
<p align="center">
  Figure 4: The CI/CD cycle.
</p>

Another approach which extends the concept of continuous integration is [continuous delivery (CD)](https://en.wikipedia.org/wiki/Continuous_delivery) which makes sure that the code that we integrate is always in a deployable ready state to users.

**Relationship to Data Science**

Since machine learning features are also just a part of larger code base for a software project, continuous integration should also be used to prevent integration problems. In the worst case, if we don’t do it, there might be huge integration costs.

In our team, we set up a CI pipeline when putting models in production. In terms of CI pipeline for data science it is more about testing the workflow e.g. that all the scripts from data cleaning, feature extraction to model exposure work as expected. The testing part is something that we already discussed thoroughly in one of our earlier [posts](http://engineering.pivotal.io/post/test-driven-development-for-data-science/).

**Concourse**

There are many CI/CD tools out there such as [Jenkins](https://jenkins.io/), [Travis](https://travis-ci.org/) and many others. They all have their pros and cons. But in our team we mainly use Concourse. It has many advantages, for example, it treats pipelines as first-class citizens. It also uses Docker to encapsulate tests, so that everything is reproducible. A more detailed list of benefits can be found in this [blog post](https://blog.altoros.com/concourse-ci-architecture-features-and-usage.html).

## CI Example for a Smart Application Project

Now we want to illustrate a simple pipeline of how Concourse can be used in practice for a smart app project.

{{< responsive-figure src="/images/continuous-integration-for-data-science/ci-pipeline-full.png" class="center" >}}
<p align="center">
  Figure 5: Simple example for a smart app project.
</p>

Figure 5 shows the full pipeline of an example project for a smart app. In this project there are two work streams where one stream is working on the machine learning part and the other is working on the application. An application could be for example a web app, an Android app or an iOS app. Therefore we will have two different work streams (Figure 6):

{{< responsive-figure src="/images/continuous-integration-for-data-science/ci-pipeline-work-streams.png" class="center" >}}
<p align="center">
  Figure 6: Separate work streams for the application and ML part.
</p>

Figure 7 shows that those two streams have different workflows e.g. for the machine learning pipeline it is important that before the model can be exposed via an API, it needs to be trained and evaluated. So there is a dependency between those two steps. This can be easily handled in Concourse via the config file with a one liner (set the `passed` option):

~~~
- name: test-model-api
  plan:
  - get: data-science-repo
    trigger: true
    passed: [test-model-training]
~~~

Surely, this is just an example. In practice there might be more steps involved e.g. you might need to do feature extraction and this also another step which might involve SQL testing. Equivalently this also applies to the application workstream. In our case we only build the app.

Then at some point those two work streams need to be integrated. Figure 7 also shows that there is an integration job at the end which takes care of it.

{{< responsive-figure src="/images/continuous-integration-for-data-science/ci-pipeline-integration.png" class="center" >}}
<p align="center">
  Figure 7: Integration of the two work streams.
</p>

In Concourse, this can be easily achieved. We just need to `get` the two different repos and then use `task` to run the tests:

~~~
- name: integration
  plan:
  - get: data-science-repo
    trigger: true
    passed: [test-model-api]

  - get: application-repo
    trigger: true
    passed: [test-application-repo]

  - task: build-application-repo
    config:
      platform: linux
      image_resource:
        type: docker-image
        source: {repository: ubuntu}
      inputs:
        - name: application-repo
        - name: data-science-repo
      run:
        path: echo
        args: ["Integrate and run tests here."]
~~~

A typical integration could be that having embedded the machine learning feature into the application, a set of tests is automatically run to test the behavior of the user interface with the ML feature e.g. Apple has this QuickType predictive text feature which suggests the next words given a certain word before. In the integration part, we could test if the output of the suggestion bar is given as expected (see Figure 8). There are many other examples how we could test the intergration part but you should understand the concept through this simple example though.

{{< responsive-figure src="/images/continuous-integration-for-data-science/apple-quick-type.jpeg" class="center" >}}
<p align="center">
  Figure 8: Apple’s QuickType predictive text feature. Photo source: [iMore](http://www.imore.com/how-use-quicktype-keyboard-iphone-and-ipad).
</p>

Finally, the last step would be to deploy the application, either manually or automatically depending on your deployment strategy. In our example, we are automatically deploying it to [Pivotal Web Services](https://run.pivotal.io/), a hosted version of [Pivotal Cloud Foundry](https://pivotal.io/platform). Figure 9 shows that we are using the [cf resource](https://github.com/concourse/cf-resource) to do it. In general, we are not limited to it. There are many [third-party resource types](https://concourse.ci/resource-types.html) for Concourse and if one is missing, you can easily build your own resources.

{{< responsive-figure src="/images/continuous-integration-for-data-science/ci-pipeline-deployment.png" class="center" >}}
<p align="center">
  Figure 9: Deployment of the smart application.
</p>

## Conclusion

We showed that the integration problem is not only a software engineering problem but also very important for smart apps projects to mitigate the integration costs, particularly when working in a balanced team environment. We mainly use Concourse as our CI tool now due to its simplicity. You can build your own pipeline very easily in a programmatic way.

If you want to learn more:

* [Test-Driven Development for Data Science](http://engineering.pivotal.io/post/test-driven-development-for-data-science/)
* [Data Science in the Balanced Team](http://www.ianhuston.net/2016/11/data-science-in-the-balanced-team/)
* [What can data scientists learn from DevOps?](http://redmonk.com/dberkholz/2012/11/06/what-can-data-scientists-learn-from-devops/)
* [8 Pro Tips for Using Concourse CI with Cloud Foundry](https://blog.altoros.com/concourse-ci-architecture-features-and-usage.html)
* [Concourse CI](https://concourse.ci/)

