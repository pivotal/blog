---
authors:
- magarwal
categories:
- Data Science
- Pair Programming
- Agile
date: 2016-01-15T10:13:32Z
short: |
  Lets see how pair programming fits in the data science world.
title: Pairing for Data Scientists
---

Hey! Happy 2016!! I have now spent two months working on the Pivotal Labs Data Science Team in London and the journey so far has been really exciting. I have been introduced to new working methodologies in an agile data science (DS) environment, pairing being one of them. We've found that pairing works well with DS, and I wanted to share some of my experiences and tips for getting started with DS pairing.

I feel pairing can be a great enablement technique. While pairing with clients, it makes them feel more involved. By developing a use case together they understand the code base better than a regular handover session at the end of project cycle. In the process, you understand the business requirements better which helps to speed up the process. Pairing with a colleague makes exploration and development of a DS use case much more fun. Besides helping in knowledge and skill exchange it's a good way to mitigate risk.

## Pair Programming and Data Science??
{{< responsive-figure src="/images/pairing_ds_logo.png" class="right small" >}}

Hmmmm… [Pair Programming](https://blog.pivotal.io/tag/paired-programming) is exactly what it sounds. Pairing has always been one of the key programming practices followed at Pivotal Labs. If you ever get a chance to visit the Labs office you will see two developers sharing a big desk space and working on two mirrored screens simultaneously. Sounds interesting and a bit challenging…. Honestly when I first saw this alien style of programming I had concerns about how productive it could be in a DS environment. Yes we have to code as data scientist! For those who didn’t know, DS involves programming right from the initial feature creation and exploratory phase to model development and its operationalization.

### Hoops to Jump through
When you start on a DS use case your objective is fairly broad. You need to spend a lot of time to find the right way to materialize the objective. You have to 'flare and focus' repeatedly before coming up with a definite objective and shipping it as an end product.

I had my doubts about how pairing would fit this flare and focus process. It’s not equivalent to pairing in a software engineering environment where the goals are more definitive to start with and the pair can work together to materialize it in best possible manner. During DS flaring, one might come with a number of problems and consequently an even larger number of ways to tackle them; having another person in the entire development process might make this phase intense and long because different people can have different ways to approach a problem.

For DS, there is no best tool for the task at hand. If one DS is comfortable using Python that might not necessarily be the same for his/her pair. Although, this is a great opportunity to expand one’s skill set but it might be a little disconcerting to run to Google for some basic syntax check with your pair watching over you!

In general when the two individuals pairing have different levels of expertise, I don't know how daunting an experience it would be for a newbie to code in this environment or how frustrating it could be for the experienced counterpart trying to get the noobie up to speed.

### Day 3 _@Pivotal_ and henceforth..
I started pairing with [Ian Huston](https://twitter.com/ianhuston), a Senior DS in my team and started jumping through these hoops. He helped me get comfortable with the process in my first few weeks. In the exploratory phase, it actually turned out that greater the number of heads brainstorming about a problem, the faster it is to come up with a variety of routes and then narrowing it down to the most preferred one.

After an initial brainstorming, we came up with certain set of features we thought would be predictive for the problem case in hand and started to develop it. We followed a test-driven feature generation process. In a ping-pong manner, a team member would come up with a test case first and then the other would write up the functionality to implement it and then the role would reverse for the next round.

My initial concerns about working with people having varied level of experience was eased. Having an experienced person as your pair helps you understand the pros and cons of various approaches better, so you save a lot of time by choosing better. We follow [extreme programming](https://en.wikipedia.org/wiki/Extreme_programming) practices in Pivotal. Ian was kind, encouraged me to be inquisitive and welcomed a newbie’s ideas. I enjoyed my initial pairing experience and started getting used to it. Since then, I have paired with other colleagues and clients onsite and remotely and I really enjoy pairing.

{{< responsive-figure src="/images/pairing_ds.jpg" >}}

### Few Handy Tips
* Check whether you have enough data scientists to be involved in pairing! It's a resource intensive exercise.
* Have a brainstorming session at the start. Discuss various techniques that can be applied, be innovative then narrow your choices and start implementing it.
* Difference of opinion? Nothing to worry about. Take a step back, weigh the pros and cons of each approach, go ahead with the winner. In case of a tie, consult someone else on the team or try all of them out on a sample of data. Remember the entire team is responsible for the project. Personal ego can't be in the driver seat here. You'll learn how to deal with disagreements better by the end of the exercise.
* Pair with right person for the right job! Pair with fellow designers or developers during relevant stages to make the best use of resources in hand. There are no reasons why data scientists shouldn't follow balanced team approach.
* Project with vague objectives? Which DS use case isn't to start with. Make progress iteratively rather than trying to figure the entire game plan from the start.

“Pairing is sharing” as one of my colleagues always tells me :). It is a concentrated cohesive effort that helps in fast iterative development, a great way to enable each other and develop something in synergy.

_Above all pairing is a great bonding exercise, I would really recommend giving it a shot!_
