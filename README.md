# The Pivotal Engineering Journal

Welcome to our little slice of the internets!  This blog is dedicated to technical (and cultural) posts by the Pivotal Engineering team.  If that's you, then *please*, *please*, *please* contribute!

[Live site](http://engineering.pivotal.io/) | [Staging](http://pivotal-cf-blog-staging.cfapps.io/) | [Issues](https://github.com/pivotal/blog/issues) | [Pull Requests](https://github.com/pivotal/blog/pulls) | [Hugo](http://gohugo.io/) | [![Build Status](https://travis-ci.org/pivotal/blog.svg?branch=master)](https://travis-ci.org/pivotal/blog)

## Contributing

1. [Write your post](https://github.com/pivotal/blog#writing-a-post) as a draft.
1. [Preview it](http://pivotal-cf-blog-staging.cfapps.io/) on staging.
1. [Make it good](https://github.com/pivotal/blog#writing-a-good-post). Gather feedback from your engineering peers.  Iterate, repeat.
1. Ship it!

Every commit to master is [auto-deployed to both production and staging](https://travis-ci.org/pivotal/blog/builds) (only staging shows drafts).  If you don't have push access, then send an ask ticket to have yourself added to `all-pivots` in this org.

## Running Locally

This site uses [Hugo](http://gohugo.io) v0.14, which is easy to install:

~~~
$ brew install hugo
$ hugo version
Hugo Static Site Generator v0.14 BuildDate: 2015-06-16T21:41:12+01:00
~~~

After cloning this repository, navigate into the new directory, run `./bin/watch` in a terminal and then browse to [http://localhost:1313](http://localhost:1313) to see your local copy of the blog.

Hugo has [LiveReload](http://livereload.com/) built in, so if you have that configured in your browser, your window will update as soon as you make a change.  Hugo is *fast*, so you might not realize the reload has already happened.

## Writing a Post

1. Add yourself as an author (first time only, obvs.):

    ~~~
    $ cp ./data/authors/tammer.yml ./data/authors/bob.yml
    $ vi ./data/authors/bob.yml
    ~~~

1. Create a new draft post with `./bin/new_post name-of-post`.  This will create a new file at location `./content/post/name-of-post.md`. It's just markdown, and the template provides instructions on any advanced bits.  Be sure to change the metadata in the file's YAML front-matter -- one thing to change immediately is the `authors:` value should include the name of your author file (`bob` in the example above) in the list.

1. *Meta:* If you want to change the default new post template, it's in `./archetypes/post.md`.

## Writing a _Good_ Post

**Keep it technical.**  People want to to be educated and enlightened.  Our audience are engineers, so the way to reach them is through code.  The more code samples, the better.

**Nobody likes a wall of text.**  Use headers to break up your text.  Each image you add to your post increases its XP by 100.  Diagrams, screen shots, or humorous "meme" (_|memā|_) gifs...  They all add color.  If you don't have OmniGraffle, then submit an ask ticket.  There's no excuse for monotony.

**Your 10th grade teacher was right.**  Make use of the hamburger technique.  Your audience doesn't have a lot of time.  Tell them what you're going to write, write it, and then tell them what you've written.  Spend time on your opening.  Make it click.

**Pair all the time.**  We do everything as a team, and this is no different.  Get feedback from your friends and coworkers.  Show them the post on the staging site, and ask them to tear it apart.

**Make it pretty.** Pivotal-ui comes with a bunch of nice helpers.  Make use of them.  Check out the example styles in the default post template.

## Publishing Your Copy

Every commit to master is [auto-deployed to both production and staging](https://travis-ci.org/pivotal/blog) (only staging shows drafts).  If you don't have push access, then send an ask ticket to have yourself added to `all-pivots` in this org. To publish your draft post, simply remove the `draft: true` line from the top of your post.

## Changing the style

`./themes/pivotal-ui` is a port of the [Pivotal UI](https://github.com/pivotal-cf/pivotal-ui) project.  I basically copied the compiled css and image files over.  If you want to change the look of this site, then you should edit the templates in there.
