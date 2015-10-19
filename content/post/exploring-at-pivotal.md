---
author: Anthony Emengo
categories:
- Agile
- Exploratory Testing
- Charter
- CF Runtime
date: 2015-10-17T20:18:28-04:00
short: A candid insight into the adoption of the exploratory testing practice at Pivotal Labs.
title: Exploring at Pivotal
---

# The problem

As Agile methodologies sweep modern software development teams, a question begins to be uttered by more and more adopters:

> "What do we do with our QAs?"

Some want their QAs but demand that they complete their work in much less time - sometimes in as little as a couple hours. Many opt to remove the group from their process altogether. And some groups introduce the practice of Test-Driven-Development to, more or less, replace the work of Quality Assurance Engineers. In Agile, the faster and more continously one can ship code, the better. And there's something crippling about having your hot code being left to get cold at the inspection of a quality gatekeeper. I admit, I've never did see the appeal or benefits of Agile until I joined Pivotal. The productivity, efficiency, and consistency at which software development happens is something that I do not think that I will witness elsewhere. However, Pivotal is Agile to the bone and that means that iterations are tight, code is rarely written by yourself, and much of the testing is automated.

Pivotal strives to assure the highest level of quality with anything that we ship, especially with the [Pivotal Cloud Foundry](http://pivotal.io/platform) project. The project has hundreds of developers on it at a time. The kind of bugs that manifest aren't the typical kind that a unit test will catch. It's things like that some members your distributed system were fighting over the last slice of... allocated memory and now they refuse talk to each other. It's the kind of bugs that you cannot anticipate and thus might overlook the automated test for it. In short, the kind of things that you would expect your QA team to report.

Something that has worked well for a lot of other agile groups is to have a tester on every team that tests along side the developers working. Although that has had some success, we want to avoid having that kind of format here. There's something alarming about having a member of your team having a specialized skillset or domain of knowledge. If this member is out sick or leaves and takes all his/her abilities with them then the team is screwed. Moreover, this can be a disparaging position to many. In a way, your role is validated by having another group waiting on your work. For instance, your designer deemed necessary by the front-end engineers looking for a mock-up to implement. Comparably, your PM is deemed necessary by the engineers looking for stories to implement and acccept. If you have a tester on the team that gets to test code that is continually deployed regardless of his/her say-so, it can be demoralizing - for some.

# The solution

We try to close the gap with the concept of exploratory charter stories. The idea is that we have investigation stories catered towards testing sprinkled through the backlog that *any* member of the team can pick up. In doing the story, you'd be engaging in the practice of unscripted testing and be using a workflow similar to that of QA doing some exploratory testing themselves. In general they look like this.

{{< figure src="/images/sample-charter.png" class="center" >}}

Anyone who has done charter based exploratory testing will feel right at home with these. In general, these can work out quite well. The typical use case is a team might create a charter story after a track of work that needs extra validation before a release or turning on a feature flag. There are modest and amibitious goals with respect to this exploratory testing initiative. If the goal is simply to provide a new tool that a team can use to perform extra checks on a project that is being delivered, then I think the practice of exploratory charters are well on its way to that. However, if we want to introduce something embedded to the culture of Pivotal that completes our definition of test coverage and bolsters our confidence in the product that we are shipping, then we could do more work on the concept of explorating testing here at Pivotal.

## The problem with the solution

The biggest problem is knowing when you should write a charter. It is a non-trivial issue that I do not think gets experienced elsewhere. We want to restrict the charters for high-risk areas of your application, but saying you can know that before the fact also implies that you can know where bugs will lie before they happen. We try to provide that 'intuition' by having explorers who frequently rotate among teams that have a strong sense of where bugs normally lie and can, by pairing, transfer this. Still, intuition is a very slippery notion and not something that one can easily ascertain as being transferred. Furthermore, bugs aren't simply in the high-risk places but also in the areas of low-risk or places you would not expect them to be. Although we purposefully want to restrict exploration, so that developer time is not encumberred, we risk missing the test coverage that we could be getting.

Another problem is the low level of interest around performing charters, especially with developers. The day to day is demanding enough, but having to derail usual feature work to go spelunking on the feature that you might have delivered days ago seems like a step backwards. They wonder what they're looking for or how chartered explorations are different from their usual delivery process. It could be argued that the reason is simply that exploring is too boring, but my hypothesis is that typical developers aren't wired for this kind of work.

Although I, myself, am an explorer here at Pivotal, I also build iOS apps in my spare time - with some deployed to the App Store. My testing for my apps are purely exploratory. Every code change, every styling change, anything change I do, I re-enact the entire user flow to get the relevant view and inspect it. It's the equivalent of performing your regression suite manually. It is still exploratory in nature in that it still leaves room for unscripted testing based on what I might notice. It might seem incredibly slow and tedious but I prefer it that way. In fact I believe it to be the ideal form of testing. What people are missing is that exploratory testing isn't simply about finding bugs, it is about becoming _intimate_ with your application. I want to know every time it sneezes and not through some analytics software but with my own eyes. And when you get to that point of trying your login screen for the thousandth time, finding bugs or thinking up edges cases to explore is trivial. I'd argue that the best explorers are motivated simply by the desire to ~~learn~~ experience every single thing about how their software behaves and by nothing else.

But like I said developers are wired differently. Developers are motivated by the tangible. Code, features, points are tangible units of work. Something that can be shown off or argued about. Your initimacy with a project is something different. Furthermore it is a lot easier for be more passionate about the application that you built from the ground up than a project that you've just been rolled on to. And, of course, my method of testing simple iOS apps doesn't scale well for bigger applications encompassing distributed systems. 

Yet, I think for this ambitious goal of embedding the exploring practice into extreme Agile domains to complete our sense of test coverage, we need to do 2 things:

1. Increase the frequency that exploration happens, these need to be prompted outside the scope of a backlog story - much like automated tests are written alongside with feature code.
1. We need to be able to generate a measurable artifact of exploration. Something akin to how code climate has made code quality quantifiable with letter grades.
