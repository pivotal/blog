---
authors:
- gabehollombe
categories:
- Rails
- Turbolinks
- iOS
date: 2016-07-29T16:52:27+08:00
draft: false
short: |
  Using Turbolinks 5 to hide your site's HTML navigation and present a native navigation view to mobile app users.
title: Building a Native Navigation Menu for iOS with Turbolinks 5
---

# Background

In [the Turbolinks 5 video from Railsconf 2016](https://www.youtube.com/watch?v=SWEts0rlezA), we learn that Turbolinks now comes with native iOS and Android adapters.  This is great because it gives us an easy way to create apps made mostly of web views, while giving us an escape hatch to leverage native views where we need them.  I wanted to see this in action, so I made a very simple Rails app that shows navigation in the HTML for web users, and an iOS app that replaces the HTML navigation links with native controls instead. Here's a walkthrough of how I did it.

**Please Note:** While this code totally works, and illustrates a lot of useful concepts that you'll need to know, I might not be doing things in the most idiomatic way. I'm *super* new to iOS programming. What you read below is the result of what I've figured out how to do, not an endorsement of the best way to do it.

## What We Want

We want a web app that shows a navigation menu to visitors coming from web browsers:

{{< responsive-figure src="/images/turbolinks-5-with-native-navigation/turbolinks_nav_web_user.gif" >}}

But for users who load the site through a mobile app using Turbolinks, we want to render the navigation using native views:

{{< responsive-figure src="/images/turbolinks-5-with-native-navigation/turbolinks_nav_ios_user.gif" style="border: 1px solid gray;" >}}

Here's how we do it...

## The Rails App

See the demo code here: https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/tree/master/rails_app - This is the app in its finished state. Below are the steps you'll need to follow if you're modifying an existing app.

First, make sure you follow the [Turbolinks installation instructions for Rails](https://github.com/turbolinks/turbolinks).

The Rails app [checks for a custom user-agent string](https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/blob/master/rails_app/app/controllers/application_controller.rb#L14) to determine if a request came from the iOS app or not. If so, it'll send the nav info over to the mobile app via JSON.

The server side part of this is straightforward. Inside the Rails app, the important files to look at are (linked for your reference):

1. [`app/controllers/application_controller.rb`](https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/blob/master/rails_app/app/controllers/application_controller.rb) where we define two helpers for our application layout to use.

1. [`app/views/layouts/application.html.erb`](https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/blob/master/rails_app/app/views/layouts/application.html.erb) where we set up the conditional navigation so it shows HTML for non-mobile-app requests and sends the nav info via JSON for mobile-app requests.


## The iOS App

See the demo code here: https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/tree/master/ios_app - This is the app in its finished state. Below are the steps you'll need to follow if you start with the iOS Turbolinks Quickstart guide.

The iOS app uses [one main view controller](https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/blob/master/ios_app/ios_app/ApplicationController.swift), an instance of `UINavigationController` to show our web app and a [simple UITableView](https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/blob/master/ios_app/ios_app/NavMenuController.swift) to render our nav menu.

First, follow the [Turbolinks for iOS Quick Start guide](https://github.com/turbolinks/turbolinks-ios/blob/master/QuickStartGuide.md).

Then, inside the iOS app, the important files to look at are (linked for your reference):

1. [`AppDelegate.swift`](https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/blob/master/ios_app/ios_app/AppDelegate.swift) where we remove all the boilerplate stuff from the Quick Start guide (it gets moved into `ApplicationController`).

1. [`ApplicationController.swift`](https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/blob/master/ios_app/ios_app/ApplicationController.swift) where we configure the custom user agent for the Turbolinks client to use and register a listener so that the page can send JSON over to Swift land.  Then, we implement the `UINavigationController`'s `willShowViewController` delegate method so we can add a nav menu button to the Nav Bar of the Turbolinks `VisitableViewController` that gets loaded and shown for a page.

1. [`NavMenuController`](https://github.com/pivotal-sg/turbolinks-5-native-navigation-demo/blob/master/ios_app/ios_app/NavMenuController.swift) where we tell the table view to look at the `title` property for each nav menu item from the JSON our web app sent, and we trigger `ApplicationController`'s `visit()` method when someone taps on a row in our menu.

## Wrapping Up & Further Reading

And there you have it. Hopefully you've seen how easy it is to wrap your web app into an iOS app with Turbolinks 5, replacing HTML with native controls as needed. If you wanted to take this demo code further, you could make the menu prettier, or animate when it toggles.

Be sure to check out the [Turbolinks iOS Demo app](https://github.com/turbolinks/turbolinks-ios#running-the-demo). You'll see how to intercept link clicks to load native views, how to control access to authenticated portions of your web app, and more.
