# Blog Pushpop

This directory is for the [Pushpop](https://github.com/pushpop-project/pushpop) configuration for our blog. It sends regular reports about traffic, etc.

Not much to see here, honestly.

Run the job just once with:

```
pushpop jobs:run_once --file jobs/keen_email_job.rb
```

*This will send an email.*

To do a dryrun without sending an email, `export DRYRUN=true`.
