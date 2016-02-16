---
authors:
- aemengo
categories:
- Agile
- Exploratory Testing
- Charter
- CF Runtime
date: 2016-02-15T20:18:28-04:00
draft: false
short: A candid insight into the adoption of the exploratory testing practice at Pivotal Labs.
title: Exploring at Pivotal
---

# The problem

As Agile methodologies sweep modern software development teams, a question begins to be uttered by more and more adopters:

> "What do we do with our QAs?"

Some want their QAs but demand that they complete their work in much less time - sometimes in as little as a couple hours. Many opt to remove the group from their process altogether. And some groups introduce the practice of Test-Driven-Development to, more or less, replace the work of Quality Assurance Engineers. In Agile, the faster and more continously one can ship code, the better. And there's something crippling about having your hot code being left to get cold at the inspection of a quality gatekeeper. I admit, I've never did see the appeal or benefits of Agile until I joined Pivotal. The productivity, efficiency, and consistency at which software development happens is something that I do not think that I will witness elsewhere. However, Pivotal is Agile to the bone and that means that iterations are tight, code is rarely written by yourself, and much of the testing is automated.

Pivotal strives to assure the highest level of quality with anything that we ship, especially with the [Pivotal Cloud Foundry](http://pivotal.io/platform) project. The project has hundreds of developers on it at a time. The kind of bugs that manifest aren't the typical kind that a unit test will catch. It's things like that some members your distributed system were fighting over the last slice of... allocated memory and now they refuse talk to each other. It's the kind of bugs that you cannot anticipate and thus might overlook the automated test for it. In short, the kind of things that you would expect your QA team to report.

Something that has worked well for a lot of other agile groups is to have a tester on every team that tests in tandem with the developers working. Although that has had some success, we want to avoid having that kind of format here. There's something alarming about having a member of your team having a specialized skillset or domain of knowledge. If this one member is out sick or leaves and takes all his/her abilities with them then the team is at a disadvantage. Moreover, this can be a disparaging position to many. In a way, your role is validated by having another group waiting on your work. For instance, your designer deemed necessary by the front-end engineers looking for a mock-up to implement. Comparably, your PM is deemed necessary by the engineers looking for stories to implement and acccept. If you have a tester on the team that gets to test code that is continually deployed regardless of his/her say-so, it can be demoralizing - for some.

# The solution

We try to close the gap with the concept of exploratory charter stories. The idea is that we have investigation stories catered towards testing sprinkled through the backlog that *any* member of the team can pick up. In doing the story, you'd be engaging in the practice of unscripted testing and be using a workflow similar to that of QA doing some exploratory testing themselves. In general they look like this.

{{< figure src="/images/sample-charter.png" class="center" >}}

Anyone who has done charter based exploratory testing will feel right at home with these. The typical use case is a team might create a charter story after a track of work that needs extra validation before a release or turning on a feature flag. The power of this approach comes in knowing how to use it effectively with your overall testing strategy. On the one hand, you *must* have your developers covering your bases with automated regression tests written while the code is written. Then you have your product manager checking for lapses in the usability or business facing requirements while performing acceptance tests on delivered work. Exploratory testing offers the chance to catch the relevant edge cases that might slip through the other stages of your testing in a way that only human **intuition** can. More importantly, it gives you the chance to learn about how product behaves. In general, these can work out quite well - if you know how to use it. 

## The problem with the solution

The most prominent problem is knowing when you should write a charter. It is a non-trivial issue that I do not think gets experienced elsewhere. We want to restrict the charters for high-risk areas of your application, but saying you can know that before the fact also implies that you can know where bugs will lie before they happen. We try to provide that **intuition** by having **explorers** who frequently rotate among teams that have a strong sense of where bugs normally lie and can, by pairing, transfer this. Still, intuition is a very slippery notion and not something that one can easily ascertain as being transferred. Furthermore, bugs aren't simply in the high-risk places but also in the areas of low-risk or places you would not expect them to be. Although we purposefully want to restrict exploration, so that developer time is not encumberred, we risk missing the test coverage that we could be getting.

A more unsettling problem is not understanding how learning is important to the process and how it relates to testing, especially among developers. A common theme is that having to derail usual feature work, and sacrificing velocity, to go spelunking on the feature that you might have delivered days ago seems like a step backwards. One might wonder how chartered explorations differ from the usual delivery process or even the process of reading documentation while working on a story. The issue is that these individuals are purely looking for bugs, as a return on investment, for the time spent not writing code. Exploratory testing is about much more than just that.

Although I, myself, am an **explorer** here at Pivotal, I also build iOS apps in my spare time - with some deployed to the App Store. My testing for my apps are purely exploratory. Every code change, every styling change, anything change I do, I re-enact the entire user flow to get the relevant view and inspect it. It's the equivalent of performing your regression suite manually, but it is still exploratory in nature in that it still leaves room for unscripted testing based on what I might notice. It might seem incredibly slow and tedious but I prefer it that way. In fact I believe it to be the ideal form of testing. What people are missing is that exploratory testing isn't simply about finding bugs, it is about becoming _intimate_ with your application. I want to know every time it sneezes and not through some analytics software but with my own eyes. And when you get to that point of trying your login screen for the thousandth time, finding bugs or thinking up edges cases to explore is trivial. I'd argue that the best explorers are motivated simply by the desire to ~~learn~~ experience every single thing about how their software behaves and by nothing else.

## The Truth

Of course, not everyone is wired like that. Many developers are motivated by the tangible. Code, features, points are tangible units of work. They're things that can be shown off or argued about. Your initimacy with a project is something akin to inner beauty. Furthermore it is a lot easier to be more passionate about the application that you built from the ground up than a project that you've just been rolled on to. *But* it does not matter. If there's anything true in this world, it is this: Whoever knows the most, finds the most bugs, period. You just recognize issues faster, your **intuition** is more effective; and most importantly, what you know you don't know usually leads to more fruitful investigations. If you can find a way to know the most about your product by a better means than exploratory testing then, by all means, do it. And then tell me about it.
