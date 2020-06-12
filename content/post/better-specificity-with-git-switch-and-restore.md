---
authors:
- rtay
categories:
- Git
date: 2020-05-31T18:44:22+0800
draft: true
title: Better specificity with git switch and restore
image: images/better-specificity-with-git-switch-and-restore/git-checkout-git-switch-restore-rosetta-stone.png
---

You probably work with Git everyday. If you've worked with Git for some time, you might have a couple of commands stored to your muscle memory - from `git commit` for recording your changes, to `git log` for sensing "where" you are.

I found `git checkout` to be a command that I reach for pretty frequently. This is not surprising, as it performs more than one operation. But in the spirit of "do one thing, and do it well", is this too many? Let's take a look at what `git checkout` can do to see what those operations are.

## Quick, what does `git checkout` do?

Perhaps you were trying something out and made some changes to the files in your local Git repository, and you now want to discard those changes. You can do so by calling `git checkout` with one file path or more:

```bash
$ git checkout path/to/file.lang
```

To be precise, the above sets the specified files paths to their content [^content-trees] in the *index*. If you'd like to set the files to their content in a *tree*, like a branch or a commit, instead of the index, specify it before the file paths. If it happens that the branch shares a name with the file, pass the `--` to separate the two. [^checkout-overwrites-index]

```bash
$ git checkout wip path/to/file.lang
$ git checkout wip -- path/to/file.lang
```

Let's put it down:
- `git checkout <filepath>` sets `<filepath>` to their contents in the index.

[^checkout-overwrites-index]: Note that the changes will be staged after running the command - or to use Git parlance, the index is overwritten.

[^content-trees]: I used "contents of files", when it is more accurate to talk about the "working tree" as something separate from the index. The ["Three Trees" section](https://git-scm.com/book/en/v2/Git-Tools-Reset-Demystified#_the_three_trees) of the freely available Pro Git book explains what they are (with diagrams!)

## Branches

Say you wanted to return to a branch, `wip`, you had been working on previously; you can run the below to set it to be the branch you're on and "checkout" [^old-checkout-desc] its files:

```bash
$ git checkout wip
```

You might have encountered `-`:

```bash
$ git checkout -
```

This checks out the last branch you were on. This is much like how `cd -` in your shell changes you back to the last directory you were in.

[^old-checkout-desc]: That the `git checkout` command does a "checkout" of branches or files was in fact the description used in its documentation in earlier versions of Git, like in [v1.7.0](https://github.com/git/git/blob/v1.7.0/Documentation/git-checkout.txt).

Let's add that our list of what `git checkout` does:
- When given a file path, `git checkout <filepath>` sets `<filepath>` to their contents in the index.
- When given a branch, `git checkout <branch>` sets the branch we're on to `<branch>` - or to be accurate, sets `HEAD` to point to `<branch>`.

## What is HEAD?

Before continuing, let's look at what `HEAD` is.

One of Git's roles is to track content, and it helps us to know what changes we have. But for Git to know what changes been made, saying a file has changed - but against what? What point of comparison does Git use to determine changes in a file?

`HEAD` plays a role in this - by setting `HEAD`, like to a branch in the second operation we looked at, Git would report changes by comparing it against the contents of the branch `HEAD` points to [^HEAD-simple]. Both `HEAD` and the branch would reference the same commit.

{{<responsive-figure src="/images/better-specificity-with-git-switch-and-restore/HEAD-diagram.svg" alt="Commit history illustration with HEAD and branches">}}

[^HEAD-simple]: When determining what has changed, `HEAD` isn't the only factor - it depends on how you ask Git for changes. For example, `git diff` uses the index as the point of comparison, so even if your files didn't match their content in `HEAD` but had been staged, you'd get an empty output. It's also important to note that Git doesn't deal with changes or deltas - each commit is a complete snapshot of your files.

[^HEAD-what]: I omitted providing a definition for `HEAD` as it didn't fit in with the post. Here goes - unlike references like branches and tags, `HEAD` is a symbolic reference. Think of it as a symlink - when you write to a symlink, the underlying backing file also changes. Apart from `HEAD`, are there other kinds of symbolic references? It turns out, there aren't many others - just one other, in fact. <https://stackoverflow.com/a/5000668>

## Detached HEAD

Apart from setting `HEAD` to point to a named branch, you can also point it to a commit, which brings us to another `git checkout` operation. To see why we would want to do so, let's continue your hypothetical workday - you now start seeing, say, a page to be laid out weirdly, but you remember it being pixel-perfect when you last worked on it about a week ago, say commit `f7884`. To confirm your hypothesis, you can explore your project's state as-of commit `f7884` and set the contents of the files in your Git repository correspondingly via:

```bash
$ git checkout f7884
```

Apart from setting the contents of your files, it also sets `HEAD` to point to the commit `f7884`, unlike a branch in the second operation we looked at:

{{<responsive-figure src="/images/better-specificity-with-git-switch-and-restore/detached-HEAD.svg" alt="Commit history illustration in detached HEAD state">}}

This is known as a *detached `HEAD`* state. If you were to make a new commit in this, `HEAD` would advance accordingly, but these commits would not be reachable through the usual Git references, like branches and tags.

{{<responsive-figure src="/images/better-specificity-with-git-switch-and-restore/detached-HEAD-commit.svg" alt="Commit history illustration of new commits in detached HEAD state">}}

In fact, you can perform the same operation by invoking `git checkout` with the `--detach` argument, which is indicative of the state it results in!

```bash
$ git checkout --detach b2db3
```

Phew, that is quite a few things that `git checkout` can do:

- When given a filepath, `git checkout <filepath>` sets one or more `<filepath>` to their contents in the index.
- When given a branch, `git checkout <branch>` sets `HEAD` to point to `<branch>`.
- When given a commit, `git checkout <commit>` sets `HEAD` to point to `<commit>`.

## An alternative (or two)

This only scratches surface of the operations that `git checkout` can perform. But generally, we see that `git checkout` deals with 2 aspects of the Git repository:

  1. Changing `HEAD` to point to a branch or a commit, and
  2. Setting the contents of files.

What if we had a tool that specifically deals with one or the other? Enter `git restore` and `git switch`.

<figure class="fig-responsive">
<img src="/images/better-specificity-with-git-switch-and-restore/banana-slice.gif" style="margin-bottom: 0">
<figcaption style="margin-bottom: 1rem"><a href="https://giphy.com/gifs/drone-cut-satisfy-Eeqkz0EAtAdvq">(Source: GIPHY)</a></figcaption>
</figure>

Let's run through the 3 operations again to see how these 2 commands are used:

1. *When given a file path, `git checkout <filepath>` sets one or more `<filepath>` to their contents in the index*:

   Use `git restore` for setting the contents of files, but not change what `HEAD` points to:

   ```bash
   $ git restore <filepath>
   ```

   As a mnemonic, think back to our example - we wanted to *restore* the contents of `<filepath>` to the index and discard changes to those files.

   For the variation `git checkout <branch/commit> <filepath>` where a tree is specified that we looked at, use the `--source` argument to `git restore`:

   ```bash
   $ git restore --source <branch/commit> <filepath>
   ```

2. *When given a branch, `git checkout <branch>` sets `HEAD` to point to `<branch>`*:

   Use `git switch` to set `HEAD` to point to a branch:

   ```bash
   $ git switch <filepath>
   ```

   A useful mnemonic would be to think that we are *switching* to a branch.

3. *When given a commit, `git checkout <commit>` sets `HEAD` to point to `<commit>`*:

   Similarly use `git switch`, but you have to specify `--detach`. This helps to call out that you are putting your repository in detached `HEAD` state.


   ```bash
   $ git switch --detach <filepath>
   ```

## Sign me up - where can I use them?

`git switch` and `git restore` were introduced in Git v2.23 [released on Aug 2019](https://github.com/git/git/blob/master/Documentation/RelNotes/2.23.0.txt#L61), so you should be able to use them on a machine with an up-to-date installation of Git. You might notice their respective manpages describe them as experimental, but this probably speaks to the options that these commands take - that is, there is a possibility that a switch or argument may be added/removed/changed to have a different behaviour. I don't see these commands going away. Indeed:

- the documentation for `git checkout` links to `git switch` and `git restore`;
- the advice printed by Git when entering detached `HEAD` state gives examples using `git switch` instead of `git checkout`;

among others.

## A Rosetta Stone

To help you get started with `git switch` and `git restore`, here's a mapping from a `git checkout` invocation you may already be using in your daily workflow:

| git checkout                                                              |Change HEAD to:| Which files are changed?    | git switch/restore                       |
|---------------------------------------------------------------------------|---------------|-----------------------------|------------------------------------------|
|`git checkout <filepath>`<br>`git checkout -- <filepath>`                  |no change      | Files listed in `<filepath>`|`git restore <filepath>`                  |
|`git checkout <branch/commit> <filepath>`<br>`git checkout <branch/commit> -- <filepath>`|no change      | Files listed in `<filepath>`|`git restore --source <branch/commit> <filepath>`|
|`git checkout <branch>`                                                    |`<branch>`     | All files in repo           |`git switch <branch>`                     |
|`git checkout <commit>`<br>`git checkout --detach <commit>`                |`<commit>`     | All files in repo           |`git switch --detach`                     |

## #12SwitchRestoresSansCheckOuts Challenge

Here's my challenge to you - start using `git switch` and `git restore`! To make things fun, once you've used them 12 times or more, post as proof a screenshot of the output `history | grep -e 'git switch' -e 'git restore'` with the tag [#12SwitchRestoresSansCheckOuts](https://twitter.com/search?q=%2333SwitchRestoresSansCheckOuts).

I hope this improved user experience will be a part of your daily workflow - better yet, part of your muscle memory.

## Further Reading

- [Git Koans](https://stevelosh.com/blog/2013/04/git-koans/#s2-one-thing-well) has an alternative take on the multitude of operations `git checkout` does.
- The [git checkout](https://git-scm.com/docs/git-checkout) documentation has a full list of the options it takes. This is also where [detached `HEAD`](https://git-scm.com/docs/git-checkout#_detached_head) is explained.

## Footnotes

