---
authors:
- Add another author here
- bgrohbiel
categories:
- Mobile
- Hybrid Apps
- Ionic
date: 2016-07-26T22:13:58+01:00
draft: true
title: Writing a Hybrid Application for Production
short: Are you thinking about writing a mobile application but would you like to use web tooling? This blog post will give you an overview of different mobile hybrid approaches, guidelines to assess whether going hybrid is an option for your project and some implementation details of a hybrid framework called Ionic 2.
---

Inspiration for this blog post is Pivotal Labs engagement here in London, helping [Impossible People](http://app.impossible.com/). Our application landed in the iOS App Store after just three months of development.

<img src="/images/writing-a-hybrid-app-for-production/screenshots/0-landing-page.png" width="120">
<img src="/images/writing-a-hybrid-app-for-production/screenshots/0-feed-tab.png" width="120">
<img src="/images/writing-a-hybrid-app-for-production/screenshots/1-create-post.png" width="120">
<img src="/images/writing-a-hybrid-app-for-production/screenshots/2-public-profile.png" width="120">

# Mobile development landscape

There are multiple ways of building a mobile application. Over time, more and more tools have emerged abstracting native development, including a handful of so-called _hybrid approaches_. Each of them has its own advantages and disadvantages, but they share an overarching goal: to increase code reusability and to take advantage of web tooling.

**Briefly, here are the main different flavours of mobile development:**

- **Pure web**: HTML5 provides rich functionality to build mobile experiences. Geolocation, Camera (using [WebRTC](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Taking_still_photos)), and offline support are supported by modern mobile browsers.

- **Web hybrid**: Ionic and PhoneGap work by using a WebView component to render their application. They provide a JavaScript library which can talk to the native code.

- **Native hybrid**: [React Native](https://facebook.github.io/react-native/), [NativeScript](https://www.nativescript.org/), and [Xamarin](https://www.xamarin.com/) operate in this space. They use an ahead of time compilation step to build native components. Because they are not running inside a WebView, they can make use of multi-threading to improve performance.

- **Native development**: Every platform provides a SDK to develop on their native platform using their native language. This approach involves the fewest abstraction layers and gives the developer most control.

As you can see:

> Hybrid != Hybrid

## Is a Hybrid App an option for project?

> Note: From this point on, when we use the term "hybrid" we refer to the web hybrid approach.

WebView-based hybrid applications have a reputation for janky mobile experiences due to the nature of being rendered inside a single-threaded browser. A web-based hybrid application is some number of abstraction layers further away from the hardware than it would be when developing a native application.

Whether a hybrid application is the best approach depends on your requirements. Like every tool, it needs to be applied appropriately. The following flow chart will help you determine whether the hybrid approach is a potential fit for your project.

![Hybrid Flowchart](/images/writing-a-hybrid-app-for-production/hybrid-flowchart.png)

# Ionic 2

We evaluated Ionic (Web Hybrid) and React Native (Native Hybrid) when assessing which hybrid tool could work best for us. React Native was an alluring option as the UI runs in a separate thread, freeing the application from jankiness. However, we opted for Ionic, a hybrid mobile application framework which allows web developers to create native experiences. Ionic was a more established and less risky than React Native at the time - also, we were confident that a Web Hybrid approach would be sufficient for our needs.

Ionic 2 uses [Angular](https://angular.io/) and [Cordova](https://cordova.apache.org/) under the hood. Besides having a very active community, we liked the concept of Ionic for the following reasons:

- **It is web development**: We are essentially building a web application and can use the well established web ecosystem and tool set. The team was able to apply its web expertise to developing our hybrid mobile application. As we wrote the back-end in JavaScript too, this meant less context switching during development.
- **Native look**: Ionic provides a rich set of different components which look fantastic and mimic native behavior well. This allowed us to churn through screens quickly, without compromising on great looks.
- **Native functionality**: Cordova provides Ionic with native functionality that can be integrated with little hassle. We are an abstraction layer away from native code, which means we can solve our problems without digging into native code.

> In short, we liked Ionic 2 because it helped us deliver our project goals:
- Branch out to Android soon after building a first iOS prototype
- Validate our value proposition
- Use contacts, push notifications and other native features
- Move fast and rely on the team's web development expertise

Why did we go for Ionic 2 instead of Ionic 1? Using Angular 2 would help us stay ahead of the hybrid curve and and make sure we could reuse our code in the future for web an application.

## Strengths

During development we benefitted from Ionic and its ecosystem. More specifically, there were some feats which sped up the development of our application.

### Native look

We saved valuable time building user interface components. Having a collection of components supported our approach of iterating on user design - we would first use an out-of-the-box component, then customise it as needed at a later point. This goes really well with our iterative way of working. We were able to have a functional and decently looking feature, that we could then further refine in future stories.
The [components](ionicframework.com/docs/v2/components) that Ionic 2 provides look native and imitate native behavior well. Also the [icons]([icons](http://ionicframework.com/docs/v2/ionicons) that come for free. The icons add a native flair and are generally well designed.

It was relatively easy to tweak the styles of the components to meet our branding. Sometimes it was enough to [overwrite SASS variables](http://ionicframework.com/docs/v2/theming/overriding-ionic-variables/), sometimes we applied our own iOS-specific styles.

### Native features

Despite the fact that our application uses a plethora of native functionality, yet, by using a hybrid framework, during the three months of development we did not have to understand or modify any native code. Platform-specific tools like Xcode were only needed for deployment, everything else could be done in any editor or IDE. Below are some of the native functionality that went into the  app:

- Push Notifications: to get the push notifications working on the client, it was as simple as:

```javascript
import {Push} from 'ionic-native'

setup () {
  // Establishes connection with APNS
  this.pushNotification = Push.init({ios: {alert: 'true', badge: 'true', sound: 'true'}})

  // prints the deviceToken which we need to send to Amazon SNS
  this.pushNotification.on('registration', (data) => {
    console.log(data.registrationId)
  })

  // prints the message we received from Amazon SNS
  this.pushNotification.on('notification', (data) => {
    console.log(data)
  })
}
```

- Contacts: the Cordova plugin will prompt the user for their contacts. If the user does not grant access to contacts, you can catch the promise.

```javascript
import {Contacts} from 'ionic-native'

Contacts
  .find(['emails'], {desiredFields: ['emails', 'name'], multiple: true, filter: '@'})
  .then((contacts) => {
    // contacts contains an array with all contacts matching the filter criteria
  })
  .catch(() => console.error('something went wrong'));
```

- Geolocation: simples!

```javascript
import {Geolocation} from 'ionic-native';

Geolocation.getCurrentPosition()
  .then((location) => {
    // location.coords.latitude
    // location.coords.longitude
    // location.coords.accuracy
  })
```

- Facebook integration: the plugin opens the Facebook login page in a browser and then automatically redirects back to the app once the user has signed in. We can also specify what additional data we will request from the user's Facebook profile.

```javascript
import {Facebook} from 'ionic-native'
Facebook
  .login(['friend_list', 'email'])
  .then(() => {
    // success
  })
  .catch(() => {
    // failure
  })
```

> The integration with native phone features was super simple and saved us valuable time, allowing us to focus on delivering features rather than technical nitty-gritty.

# Weaknesses

While we were all around pleased with Ionic, there are also some areas where we wished Ionic could have worked better for us:

## Testing

- Here at [Pivotal](https://pivotal.io), we do TDD and we believe that testing is the foundation of a successful application. Unfortunately, testing the application was generally not as smooth as we would have liked it to be.
- Unit tests: were easy to write as there are no or very few dependencies that need to be mocked.
- Integration tests: were hard to write as there are a lot of dependencies and we found ourselves in mocking-hell, mocking all sorts of internal objects inside Angular 2 and Ionic 2.
- End-to-end: We used [Protractor](http://www.protractortest.org/#/) and it made us cry. Unless its support for Angular 2 and Ionic was improved substantially, we would not use it again. Our end-to-end tests were rather hard to write and flaky.
    - We also found that the more native functionality we added, the harder it became to test. We suggest looking into tools like Appium to end-to-end test native functionality.
- All tests were affected by the fact that we used TypeScript and the code needed to be transpiled to JavaScript before being run.

> Generally, we would have liked more resources which cover testing and present best practices for testing components, pages and services. We lost valuable time figuring it out ourselves.

## Heisenbugs

Despite being in beta at the time, Ionic 2 was never a blocker and development was smooth. Yet, there were four rather epic bugs that we encountered over the course of the project which caused some mild mental distress! They were:

- **The black screen of death**: we would see a black screen when reopening the app after some time. An uncaught race condition stopped Ionic from executing, which meant that ion-content would not be displayed and the underlying black background of the Ionic application would appear. Using the [Cordova console plugin](https://github.com/apache/cordova-plugin-console) helped us to log more and made debugging simpler.
- **The white screen of death**: some older iPhones could not boot up the app and we would see a white screen. It took us some time to figure out that we forgot to reference the es6-shim.js file in the index.html. Without the shims, older WebKit versions throw a fit when they cannot parse the JavaScript.
- **Cordova.js**: the Cordova plugins did not work until we found out that we must include cordova.js in index.html, despite cordova.js being an empty file in the browser. When running on the client, the file will be replaced with a real file.
- **Memory leak**: when using the [Cordova Geolocation](https://github.com/apache/cordova-plugin-geolocation) the application would increase memory consumption to the maximum and then crash. This bug was fixed after the maintainer of the plugin provided a patch. Using the latest version will free you from this bug.

> The good news is that we were able to resolve all of these bugs. The bad news is that most of these bugs could have been prevented by having a better understanding of what Ionic actually does in the build process. We found that it would have been useful if we had resources about the build steps going on behind the scenes.

## Forms and inputs

We found that forms and inputs were generally a source of pain, especially on iOS. Entering form data did not feel as smooth as entering data on a truly native application. Here are a few oddities we discovered working with forms and inputs:

- On iOS devices one cannot change the keyboard action button. The only options are "Return" for textareas and "Go" for inputs. We would have liked to have more options to make our user experience better. This is however a [well-known limitation](https://github.com/driftyco/ionic-plugin-keyboard/issues/54) of hybrid applications that we were well aware of before embarking on building the app.
- On iOS devices, textareas have non-native behaviour, they scroll either too far or to the wrong position. Also, we witnessed other strange bugs where shadows would appear around inputs when scrolling slowly. Adding the [accessory bar](https://github.com/driftyco/ionic-plugin-keyboard) helped us to mitigate some of the shortcomings.

> Inputs work better on Android than on iOS, we found. On iOS the inputs were good enough for a prototype but not adequate for a quality application. We worked with our product designer to work around this.

# Deployment

Before launching our app in the App Store we used [TestFairy](https://testfairy.com/) for a closed alpha test. TestFairy can be seen as a platform-independent equivalent of Apple's [TestFlight](https://developer.apple.com/testflight/) application with the additional ability to take videos of users using the app. However, inviting iOS users to TestFairy can be a hassle as every person's device needs to be manually added to the list of testers. It does not use the distribution certificates, unlike TestFlight, which means that the number of testers is limited to 100 per device type (iPhone, iPad, etc.).

Once the alpha phase was complete, deploying to the App Store was smooth. We had no problems and our app got approved straight away without any changes. It took Apple roughly 1-2 days to go through App Store submission cycle.

> In retrospect, we would recommend submitting to the App Store as soon as possible to de-risk the submission process. We would use TestFlight over TestFairy if non-iOS support isn't needed, as one can test the app with the distribution certificates.

# Conclusion

In the course of 15 weeks we built a hybrid application with Ionic 2 that looks stunning and has allowed us to validate our value proposition. Our app is packed with native functionality and will be ported to Android with little extra effort in the near future. We have a maintainable Angular 2 codebase and can easily expose parts of it to the web, which is also on the _Impossible people_ roadmap.

A key area in Ionic 2 that needs improvement is testing. There are few resources and best practices around sensible testing strategies. In retrospect we would have probably used another tool for end-to-end testing and considered [Appium](http://appium.io/) to test our native functionality.

> Hybrid apps are not a universal choice for building mobile applications. It is important to know about their limitations and whether they clash with the project objectives. For the right product, they can be an effective tool to build a stunning mobile application in little time. [See it with your own eyes.](http://app.impossible.com/)
