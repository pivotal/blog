---
authors:
- grosenhouse
categories:
- git
date: 2017-03-08T18:01:29-08:00
draft: true
short: |
  Best practices for Git on mixed-source teams
title: "Use Git pushInsteadOf"
---

# The problem(s)
Are you're on a team that works with both public and private repositories on GitHub?  Do you prefer SSH authentication?

If so, you may have encountered one of these issues...

### Problem 1: You can't pull an open-source project

You run `git pull` in a public repo, and then you see
```text
Permission denied (publickey).
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```

That's an open-source repo: why can't you pull it?

### Problem 2: You're prompted for username + password, but you prefer SSH

You run `git pull` in a private repo, and then you see:
```text
Username for 'https://github.com': myusername
Password for 'https://myusername@github.com':
```

----


# The fix

Here's a simple 3-part workflow to correct both of those problems.

### Part 1: Global `pushInsteadOf`

In your global git configuration file, `~/.gitconfig`, add this section:

```
[url "git@github.com:"]
  pushInsteadOf = https://github.com/
  pushInsteadOf = git://github.com/
```

This ensures that pushes will always use SSH authentication, not user/password.

### Part 2: Public repos use https remote

In the local checkout for each public repo, edit the `.git/config` file to include:

```
[remote "origin"]
  url = https://github.com/cloudfoundry-incubator/cf-networking-release
```

This is important so that you can pull public remotes even without authenticating.


### Part 3: Private repos use SSH remote

In the local checkout for each private repo, edit the `.git/config` file to include:

```
[remote "origin"]
  url = git@github.com:cloudfoundry/container-networking-deployments.git
```

This ensures that git pulls will use SSH authentication, not user/password.

---

# Conclusion

That's it!  Use this wherever you're working with a mixture of open-source and closed-source repositories.

If your open-source project uses git submodules, be sure to use HTTPS for the submodule references too, so that anyone
can easily pull and checkout all your submodules, even if they can't authenticate against the remote.

## See also:

- [Make your own encrypted USB drive for SSH keys](http://tammersaleh.com/posts/building-an-encrypted-usb-drive-for-your-ssh-keys-in-os-x/)
- [git push in the Git Book](https://git-scm.com/docs/git-push/)
- [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
