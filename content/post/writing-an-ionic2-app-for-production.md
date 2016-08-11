---
authors:
- bgrohbiel
categories:
- Mobile
- Hybrid Apps
- Ionic
date: 2016-08-04T21:55:58+01:00
title: Writing an Ionic 2 Application for Production
short: On a recent Pivotal Labs engagement, we built a hybrid application using Ionic 2. This post provides some technical considerations for building your own.
---

Inspiration for this blog post is a recent Pivotal Labs engagement here in London, helping Impossible, a social giving startup, develop a [mobile app](http://app.impossible.com/). Our application landed in the iOS App Store after just three months of development.

# Mobile development landscape

There are multiple ways of building a mobile application. Over time, more and more tools have emerged abstracting native development, including a handful of so-called _hybrid_ approaches. Each of them has its own advantages and disadvantages, but they share an overarching goal: to increase code reusability and to take advantage of web tooling.

**Briefly, here are the main different flavours of mobile development:**

- **Pure web**: HTML5 provides rich functionality to build mobile experiences. Geolocation, Camera (using [WebRTC](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API/Taking_still_photos)), and offline support are supported by modern mobile browsers.

- **Web hybrid**: Ionic and PhoneGap work by using a WebView component to render their application. They provide a JavaScript library which can talk to the native code.

- **Native hybrid**: [React Native](https://facebook.github.io/react-native/), [NativeScript](https://www.nativescript.org/), and [Xamarin](https://www.xamarin.com/) operate in this space. They use an ahead of time compilation step to build native components. Because they are not running inside a WebView, they can make use of multi-threading to improve performance.

- **Native development**: Every platform provides a SDK to develop on their native platform using their native language. This approach involves the fewest abstraction layers and gives the developer most control.

As you can see:
<div class="bg-neutral-9" style="border-left: 5px solid #A2B1B5; padding: 10px">
  Hybrid != Hybrid. For our project, we chose the Web Hybrid approach, namely Ionic 2.
</div>

## Is Ionic an option for you?

Webview-based hybrid applications have a reputation for janky mobile experiences due to the nature of being rendered inside a single-threaded browser. A web-based hybrid application is some number of abstraction layers further away from the hardware than it would be when developing a native application.

Whether a hybrid application is the best approach depends on your requirements. We developed the following flow chart to help you determine whether the Ionic is a potential fit for your project.

![Hybrid Flowchart](/images/writing-an-ionic2-app-for-production/hybrid-flowchart.png)

# Ionic 2

Ionic is using [Angular](https://angular.io/) and [Cordova](https://cordova.apache.org/) under the hood. Besides having a very active community, we liked the concept of Ionic for the following reasons:

- **It is web development**: We were essentially building a web application and can use the well established web ecosystem and tool set. The team was able to apply its web expertise to developing our hybrid mobile application. As we wrote the back-end in JavaScript too, this meant less context switching during development.
- **Native look**: Ionic provides a rich set of components which look fantastic and mimic native behavior well. This allowed us to churn through screens quickly, without compromising on great looks.
- **Native functionality**: Cordova provides Ionic with native functionality that can be integrated with little hassle. When using Ionic, we are an abstraction layer away from native code, which means we can solve our problems without digging into native code.
- **Platform portability**: We first focused on building an iOS app. hile we focused on building an iOS app first, the product team may want to branch out to Android soon. By using Ionic, we will be able reuse the majority of our codebase.

## Strengths

During development we benefitted from Ionic and its ecosystem. More specifically, there were some properties which sped up the development of our application dramatically.

### Styles, Components and Icons

We saved valuable time building user interface components. Having a collection of components supported our approach of iterating on user design - we would first use an out-of-the-box component, then customise it as needed at a later point. This goes really well with our iterative way of working. We were able to use components to build functional and decently looking features, that we could then further down the line.
The [components](ionicframework.com/docs/v2/components) that Ionic 2 provides look native and imitate native behavior well, and the [icons]([icons](http://ionicframework.com/docs/v2/ionicons) (or ‘Ionicons’ as Ionic calls them!) come for free. The icons add a native flair and are generally well designed.

It was easy to tweak the styles of the components to meet our branding. Sometimes it was enough to [overwrite SASS variables](http://ionicframework.com/docs/v2/theming/overriding-ionic-variables/), sometimes we applied our own iOS-specific styles. iOS developers tell us that when deviating from the default iOS styles, styling becomes difficult. Thanks to CSS and Ionic's modular styles, deviating from the default is not an issue.

### Support for Native Features

Despite the fact that our application uses a plethora of native functionality, by using a hybrid framework, during the three months of development we did not have to understand or modify any native code. Platform-specific tools like Xcode were only needed for deployment, everything else could be done in any editor or IDE. Below are some of the native functionality that went into the  app:

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

<div class="bg-neutral-9" style="border-left: 5px solid #A2B1B5; padding: 10px">
The integration with native phone features was super simple and saved us valuable time, allowing us to focus on delivering and ultimately validating features rather than technical nitty-gritty.
</div>

# Weaknesses

While we were all around pleased with Ionic, there are also some areas where we wished Ionic could have worked better for us:

## Testing

Here at [Pivotal](https://pivotal.io), we do TDD and we believe that testing is the foundation of any successful software project. Unfortunately, testing the application was generally not as smooth as we would have liked it to be.
  - **Unit tests**: were easy to write as there are no or very few dependencies that need to be mocked.
  - **Integration tests**: were hard to write as there are a lot of dependencies and we found ourselves in mocking-hell, mocking all sorts of internal objects inside Angular 2 and Ionic 2.
  - **End-to-end**: We used [Protractor](http://www.protractortest.org/#/) and the constant flakyness of our end-to-end tests was frustrating. Unless its support for Angular 2 and Ionic has improved in the meantime, we would not use it again. Also, we found that the more native functionality we added, the harder it became to test. To test native functionality we suggest looking into tools like [Appium](http://appium.io/). Appium allows developers to write tests which run in an emulator or a device, but can still assert on content rendered in the webview.

All tests were affected by the fact that we used TypeScript and the code needed to be transpiled to JavaScript before being run. This took some extra time setting up a continuous delivery pipeline.

<div class="bg-neutral-9" style="border-left: 5px solid #A2B1B5; padding: 10px">
Generally, we would have liked more resources which cover testing and present best practices for testing components, pages and services. We lost valuable time figuring it out ourselves.
</div>

## Heisenbugs

There were four rather epic bugs that we encountered over the course of the project which caused some mild mental distress! They were:

- **The black screen of death**: we would see a black screen when reopening the app after some time. An uncaught race condition stopped Ionic from executing, which meant that ion-content would not be displayed and the underlying black background of the Ionic application would appear. Using the [Cordova console plugin](https://github.com/apache/cordova-plugin-console) helped us to log more and made debugging simpler.
- **The white screen of death**: some older iPhones could not boot up the app and we would see a white screen. It took us some time to figure out that we forgot to reference the es6-shim.js file in the index.html. Without the shims, older WebKit versions throw a fit when they cannot parse the JavaScript.
- **Cordova.js**: the Cordova plugins did not work until we found out that we must include cordova.js in index.html, despite cordova.js being an empty file in the browser. When running on the client, the file will be replaced with a real file.
- **Memory leak**: when using the [Cordova Geolocation](https://github.com/apache/cordova-plugin-geolocation) the application would increase memory consumption to the maximum and then crash. This bug was fixed after the maintainer of the plugin provided a patch. Using the latest version will free you from this bug.

<div class="bg-neutral-9" style="border-left: 5px solid #A2B1B5; padding: 10px">
The good news is that we were able to resolve all of these bugs. The bad news is that most of these bugs could have been prevented by having a better understanding of what Ionic actually does during its build process. We found that it would have been useful if we had resources about the build steps going on behind the scenes. As soon as you have a problem that involves the Ionic CLI, things become hairy and hard to fix.
</div>

## Forms and inputs

We found that forms and inputs were generally a source of pain, especially on iOS. Entering form data did not feel as smooth as entering data on a truly native application. Here are a few oddities we discovered working with forms and inputs:

- On iOS devices one cannot change the keyboard action button. The only options are "Return" for textareas and "Go" for inputs. We would have liked to have more options to make our user experience better. This is however a [well-known limitation](https://github.com/driftyco/ionic-plugin-keyboard/issues/54) of hybrid applications that we were well aware of before embarking on building the app.
- On iOS devices, textareas have non-native behaviour, they scroll either too far or to the wrong position. Also, we witnessed other strange bugs where shadows would appear around inputs when scrolling slowly. Adding the [accessory bar](https://github.com/driftyco/ionic-plugin-keyboard) helped us to mitigate some of the shortcomings.

<div class="bg-neutral-9" style="border-left: 5px solid #A2B1B5; padding: 10px">
We observed that inputs work better on Android than on iOS. On iOS the inputs were good enough for a prototype but not adequate for a quality application. To make it work, our product designer had to come up with flows to hide the problems.
</div>

# Conclusion

<div class="bg-neutral-9" style="border-left: 5px solid #A2B1B5; padding: 10px; margin-bottom: 15px">
Hybrid development remains a controversial topic and hybrid apps will never be a universal choice for building mobile applications. For successful hybrid project, it is important to know about their limitations and whether they clash with the project objectives. For the right product, they can be an effective tool to build a stunning mobile application in little time.
</div>

In 15 weeks we built a production-ready application with Ionic 2. The application looks stunning and has allowed us to start validating our value proposition. Our app is packed with native functionality and could be ported to Android with little extra effort in the near future. We have a maintainable Angular 2 codebase and can easily expose parts of it to the web. While there are some quirks that might give away (especially to developers) that there might be a hybrid application under the hood, the feel of the application is very close to a truly native application.

*I would like to thank Hilary Johnson (Product Manager, Pivotal Labs) for inspiring me to write this blog post and her valuable feedback throughout the process. Also, a big "thank you" goes out to Senior Software Engineer, Jonathan Sharpe and his invaluable contributions during the project, which surfaced many interesting aspects of Ionic. Last but not least, I thank all the other brave Pivots that helped me getting this blog post on the way.*
