---
authors:
- cunnie
categories:
- 2FA
- TOTP
- Google Authenticator
date: 2019-01-21T11:16:22Z
draft: false
short: |
  Time-based One-time Passwords (TOTP)authenticators apps are often deployed on
  smartphones to enhance security of sensitive online accounts; however,
  replacing the phone typically requires a burdensome reset of *all* TOTP
  passwords. In this blog post we describe the clever use of a QR code reader,
  secure storage, bash scripting, a QR code generator to quickly configure a new
  phone (no reset of TOTP required).
title: Transferring Time-based One-time Passwords to a New Smartphone
image: /images/pairing.jpg
---

## Abstract

Smartphone authenticator apps such as [Google
Authenticator](https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2)
and [Authy](https://authy.com/) implement software tokens that are ["two-step
verification services using the Time-based One-time Password Algorithm (TOTP)
and HMAC-based One-time Password algorithm
(HOTP)"](https://en.wikipedia.org/wiki/Google_Authenticator)

Smartphone TOTP, a form of Two-factor authentication (2FA), display a 6-digit
code derived from a shared secret, updating every thirty seconds.

The shared secret is presented only once to the user, typically in with a [QR
(Quick Response) Code](https://en.wikipedia.org/wiki/QR_code) which is scanned
in by the authenticator app.

By using a simple QR app (not an authenticator app) to read in the shared
secret, and storing the shared secret in a secure manner, one can easily recover
the state of the authenticator app on a replacement phone.

{{< responsive-figure src="https://user-images.githubusercontent.com/1020675/51432831-2566ae80-1bf3-11e9-9a3f-5dce004e9efd.png" class="center" alt="Google Authenticator Screenshot" title="The Google Authenticator app running on an Android phone displaying the TOTP codes for several services, including Okta (shown), GitHub, and LastPass" >}}

This procedure is designed for an Android phone and a macOS workstation, but can
be adapted to an iOS phone or Linux workstation, and, with some work, to a Windows
workstation.

## Procedure

<div class="alert alert-warning" role="alert">

The process described here is not lightweight—it's as burdensome as  resetting
all your TOTP secrets. The target user is someone who prefers TOTP 2FA over SMS
2FA and who frequently upgrades phones (or factory resets them). Or someone who
keeps spare phones.

</div>

### 0. Scan in the QR URL

When scanning in a new TOTP code, rather than bringing up Google Authenticator,
we use Android Camera's builtin QR Code reader (we're not familiar with
iOS/iPhones, but we assume there is an equivalent feature):

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/51447249-03435e00-1cd1-11e9-89b5-0d764795e24a.jpg"
class="center" alt="Scanning in a TOTP QR code" title="The Android Camera has a QR code reader mini-app. The launch button (see arrow) displays when the camera recognizes a QR code" >}}

_The gentle reader should rest assured that all secrets in this blog post are
fakes and that we would not deliberately leak our TOTP secrets in such an
indiscreet manner._

Once in the QR mini-app, we copy the link to the clipboard by pressing the
"duplicate" icon. A typical link would be similar to the following (an example
TOTP from Slack):

```
otpauth://totp/Slack (Cloud Foundry):bcunnie@pivotal.io?secret=CBL5RAL4MSCFFKMX&issuer=Slack
```

Note that the link has a _[scheme](https://en.wikipedia.org/wiki/URL)_ of
"otpauth", an _authority_ of "totp", and the secret (key) is presented as a
key-value pair query component ("secret=CBL5RAL4MSCFFKMX"). For those interested
in more detail, the [Google Authenticator GitHub
Wiki](https://github.com/google/google-authenticator/wiki/Key-Uri-Format) is an
excellent resource (where you will discover, among other things, that the key is
Base32-encoded).

{{< responsive-figure
src="https://user-images.githubusercontent.com/1020675/51447539-202d6080-1cd4-11e9-846a-563ec1874572.png" class="center" alt="Copying the TOTP URL" title="We copy the link to the clipboard by pressing the \"duplicate\" icon" >}}

### 1. Copy the URL to a password manager

We copy the URL to a password manager. In our case we use LastPass <sup><a
href="#lastpass" class="alert-link">[LastPass]</a></sup> , but we believe any
password manager will do.

_We are interested in alternative secure storage mechanisms (e.g. Vault,
1Password) for the secrets. For those of you so inclined, [pull
requests](https://github.com/pivotal-legacy/blog/edit/master/content/post/totp.md)
describing alternatives are welcome._

We copy the URL to a "secure note", one line per URL. We name the secure note
`totp.txt`.

This is what our secure note looks like (the keys have been changed to protect
the innocent):

```
otpauth://totp/Okta:bcunnie@pivotal.io?secret=ILOVEMYDOG
otpauth://totp/GitHub:brian.cunnie@gmail.com?secret=mycatisgreat2
otpauth://totp/LastPass:bcunnie@pivotal.io?secret=LETSNOTFORGETMYWIFE
otpauth://totp/LastPass:brian.cunnie@gmail.com?secret=ormylovelychildren
otpauth://totp/AWS:bcunnie@pivotal.io?secret=SOMETIMESIFORGETMYCHILDRENSNAMES
otpauth://totp/AWS:brian.cunnie@gmail.com?secret=theyrealwaysgettingintotrouble
otpauth://totp/Google:brian.cunnie@gmail.com?secret=ILETMYWIFEDEALWITHIT
otpauth://totp/Pivotal%20VPN:bcunnie@pivotal.io?secret=computersaremucheasiertohandlethankids
otpauth://totp/Coinbase:brian.cunnie@gmail.com?secret=SOMETIMESIHIDEINMYOFFICE
otpauth://totp/Joker:brian.cunnie@gmail.com?secret=buttheyopenthedoortoseehwatImdoing
otpauth://totp/Discord:brian.cunnie@gmail.com?secret=THEYGETBOREDPRETTYQUICKLY
otpauth://totp/namecheap:brian.cunnie@gmail.com?secret=soIplayminecraftwiththem
```

### 2. Display the QR code to your terminal

We make sure we have a utility which displays QR codes to our terminal; we have
found [`qrencode`](https://fukuchi.org/works/qrencode/index.html.en) quite
adequate, and on macOS it's installed as easily as `brew install qrencode`
(assuming the homebrew package manager is already installed).

We use a three-line shell script,
[`totp.sh`](https://github.com/cunnie/bin/blob/99c34d757061410984f3e66ceb9b035c6ba59eb6/totp.sh)
to display the QR codes to our terminal. Our invocation uses the LastPass CLI
to display our TOTP secrets and pipe it to our shell script:

```bash
lpass show --note totp.txt | totp.sh
```

A parade of QR codes scrolls on our terminal, and we use our authenticator app
to scan them in. We have been able to scan as many as 12 different QR codes in
under a minute!

We recommend adding the QR code on your terminal, not on the site's web page, to
the authenticator to ensure that the URL (and secret) have been correctly
copied.

## TOTP Alternatives

### SMS 2FA

SMS 2FA transparently migrates to new phones (as long as the phone number
doesn't change), but has been faulted for being vulnerable to Signaling System 7
(SS7) attacks.
[[0](https://www.theverge.com/2017/9/18/16328172/sms-two-factor-authentication-hack-password-bitcoin)]
[[1](https://www.kaspersky.com/blog/2fa-practical-guide/24219/)]
[[2](https://www.theregister.co.uk/2018/08/01/reddit_hacked_sms_2fa/)]

### U2F 2FA

["Universal 2nd Factor (U2F) is an open authentication standard that strengthens
and simplifies two-factor authentication (2FA) using specialized Universal
Serial Bus (USB) or near-field communication (NFC)
devices"](https://en.wikipedia.org/wiki/Universal_2nd_Factor)

U2F's advantage is that its secret is never shared (it never leaves the key), so
the secret itself is difficult to compromise.  The downside is that the secret
is stored in a physical key, so if the key is lost or broken, the 2FA must be
reset. Also, adoption of U2F is not as widespread as TOTP: Slack, for example,
offers [TOTP 2FA but not U2F
2FA](https://get.slack.help/hc/en-us/articles/204509068-Set-up-two-factor-authentication)
as of this writing.

## Further Reading

[CNET](https://www.cnet.com/how-to/how-to-move-google-authenticator-to-a-new-device/)
describes a procedure which doesn't require storing the secrets but does require
visiting each TOTP-enabled site to scan in the a new QR code. It also requires
the old phone (it's not much help if you lose your phone).

[Protectimus](https://www.protectimus.com/blog/google-authenticator-backup/)
suggests saving screenshots of your secret keys, a simple solution for the
non-technical user. They also describe a very interesting mechanism to extract
the keys from a rooted phone using
[adb](https://developer.android.com/studio/command-line/adb) and SQLite, a
technique which may be useful for users who already have a rich set of TOTP
sites but have not stored the URLs in a password manager.

## Footnotes

<a name="lastpass"><sup>[LastPass]</sup></a>
The security-minded reader might ask, "Wait, you're storing your TOTP secrets in
LastPass, but isn't that also where you're storing your passwords? Isn't that a
poor choice — to store both your secrets and passwords in the same place?"

To which we reply, "Yes, it is often poor choice to store both your secrets and
passwords in the same place, but never fear — we don't store our passwords in
LastPass. Yes, we are aware that the intent of LastPass is to store passwords,
but that's not what we use it for. Instead, we store our passwords in a
blowfish2-encrypted flat file in a private repo. We use LastPass for storing
items that are sensitive but not passwords (e.g. TOTP keys)."
