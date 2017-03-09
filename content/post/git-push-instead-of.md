---
authors:
- grosenhouse
categories:
- git
date: 2017-03-08T18:01:29-08:00
draft: false
short: |
  Best practices for Git on mixed-source teams
title: "Git pushInsteadOf"
---

*Here's how to set up your workstation for easy access to both open-source and closed-source git repositories.*

---

# The problem(s)
Are you on a team that works with both public and private repositories on GitHub?  Do you use SSH authentication?
 (If not, [you should](http://tammersaleh.com/posts/building-an-encrypted-usb-drive-for-your-ssh-keys-in-os-x/).)

If so, you may have encountered one of these problems...

### Problem 1: You can't pull an open-source project

When you try to pull an open-source repo
```bash
cd my-public-repo
git pull
```
it ought to just work, regardless of whether you've added your SSH key.  But instead, you might see

```text
Permission denied (publickey).
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
```

That's an open-source repo: anyone should be able to pull it, right?

### Problem 2: You're prompted for username + password, but you prefer SSH

You add your SSH key and try to pull a private repo
```bash
ssh-add -t 1H /Volumes/my-ssh-key/id_rsa
cd my-private-repo
git pull
```
You want it to authenticate via SSH.  But instead you see:

```text
Username for 'https://github.com': myusername
Password for 'https://myusername@github.com':
```

Whoops.

----


# The fix

Here's a simple 3-part workflow to correct both of the problems above.

### Part 1: Set a global `pushInsteadOf` override

In your global git configuration file, `~/.gitconfig`, add this section:

```ini
[url "git@github.com:"]
  pushInsteadOf = https://github.com/
  pushInsteadOf = git://github.com/
```

This ensures that pushes will always use SSH authentication, even if the remote URL specifies `https://` or `git://`

### Part 2: Public repos use `https` remote

In the local checkout for each public repo, edit the `.git/config` so that the remote uses `https`:

```ini
[remote "origin"]
  url = https://github.com/myusername/my-public-repo
```

This way, you can pull public remotes without needing to authenticate.

> If you're cloning a public repo for the first time, follow the same pattern
>
```text
git clone https://github.com/myusername/my-public-repo
```


### Part 3: Private repos use SSH remote

In the local checkout for each private repo, edit the `.git/config` file to use SSH authentication:

```ini
[remote "origin"]
  url = git@github.com:myusername/my-private-repo
```

This ensures that git pulls will use your SSH key instead of prompting you for a username and password.

> If you're cloning a private repo for the first time, follow the same pattern
>
```text
git clone git@github.com:myusername/my-private-repo
```

That's it!

---

# Conclusion

Follow the steps above whenever you're working with a mixture of open-source and closed-source repositories.

If your open-source project uses git submodules, be sure to use HTTPS for the submodule references too.  This way, anyone
can easily pull and checkout all your submodules, even if they can't authenticate against the remote.

---

# Further Reading

- [Make your own encrypted USB drive for SSH keys](http://tammersaleh.com/posts/building-an-encrypted-usb-drive-for-your-ssh-keys-in-os-x/)
- [Git Push URLs](https://git-scm.com/docs/git-push/#_git_urls_a_id_urls_a)
- [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
