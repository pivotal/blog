---
authors:
- Add another author here
- tammer
categories:
- BOSH
- CF Runtime
- API
- Logging & Metrics
- Agile
date: 2015-11-17T17:16:22Z
draft: true
short: |
  Short description for index pages, and under title when viewing a post. Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam.
title: example_post
image: /images/pairing.jpg
---

Posts are written in [Markdown](https://help.github.com/articles/github-flavored-markdown/) -- tips below:

## Writing a _Good_ Post

_copied from [the README](https://github.com/pivotal/blog#writing-a-good-post)..._

### Keep it technical.

People want to to be educated and enlightened.  Our audience are engineers, so the way to reach them is through code.  The more code samples, the better.

### Nobody likes a wall of text.

{{< responsive-figure src="/images/pairing.jpg" class="right small" >}}

Use headers to break up your text.  Each image you add to your post increases its XP by 100.  Diagrams, screen shots, or humorous "meme" (_|memā|_) gifs...  They all add color.  If you don't have OmniGraffle, then submit an ask ticket.  There's no excuse for monotony.

### Your 10th grade teacher was right.

Make use of the hamburger technique.  Your audience doesn't have a lot of time.  Tell them what you're going to write, write it, and then tell them what you've written.  Spend time on your opening.  Make it click.

### Pair all the time.

We do everything as a team, and this is no different.  Get feedback from your friends and coworkers.  Show them the post on the staging site, and ask them to tear it apart.

### Make it pretty.

Pivotal-ui comes with a bunch of nice helpers.  Make use of them.  Check out the example styles below:

---

# Header 1 

Don't use this, since it looks like a main title.

## Header 2

### Header 3

#### Header 4

##### Header 5

###### Header 6

{{< responsive-figure src="/images/pairing.jpg" class="left" >}}

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.

~~~ruby
instance = Class.new("foo")
~~~

| Header 1        | Header 2  | ...        |
| --------------  | :-------: | ---------: |
| SSH (22)        | TCP (6)   | 22         |
| HTTP (80)       | TCP (6)   | 80         |
| HTTPS (443)     | TCP (6)   | 443        |
| Custom TCP Rule | TCP (6)   | 2222       |
| Custom TCP Rule | TCP (6)   | 6868       |

{{< responsive-figure src="/images/pairing.jpg" class="center" >}}
