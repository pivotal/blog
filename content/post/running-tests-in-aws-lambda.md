---
authors:
- exie
- cinnis
categories:
- AWS Lambda
- Testing

date: 2016-04-04T14:48:06-07:00
short: |
  Quickly and easily run your tests on AWS without the hassle of starting new
  EC2 instances.
title: "Running Tests in AWS Lambda"
---
## Overview

Here at Cloud Foundry, we maintain the
[`s3cli`](https://github.com/pivotal-golang/s3cli) command line wrapper for
authenticated requests to any S3 bucket or bucket in an S3-compatible storage
provider. For example, this CLI is used by the
[BOSH](https://github.com/cloudfoundry/bosh) agent and director to write and
access blobs in an [external blobstore][blobstore].

One of the responsibilities of the `s3cli` is to be able to make authenticated
requests inside AWS without the need to provide any access key IDs or secret
access keys. This works by allowing the `s3cli` to use a predefined
[IAM role][iam_role] that allows services in AWS to access other services in
your AWS account. For example, you could create an IAM role that allows the AWS
EC2 service to access S3, create an instance profile as a wrapper for this IAM
role, and then attach this instance profile to a running EC2 instance to
automatically allow any AWS SDK call running inside the instance to access S3.

## Testing in AWS EC2

Naturally, the integration testing for this functionality can only run inside
AWS, so we must come up with a solution to get fast testing for this feature
while fully testing that utilizing an IAM role works correctly for requests
to S3.

Previously we have approached this problem of testing the `s3cli` with the
following steps:

  1. Run CloudFormation to create the IAM role and instance profile along with
     a full networking stack and a brand new instance to allow for SSH access
     from our CI workers.
  1. SCP the `s3cli` binary, the tests for the `s3cli` and its dependencies
     over to the EC2 instance created.
  1. SSH to the instance and verify that the tests exited with a non-zero
     exit status.

One major problem with this approach is that the setup costs are high, as a
non-trivial amount of resources must be spun up as part of the CloudFormation
stack which takes a long time to finish. Related to this issue is that the
CloudFormation stack could fail to create for any reason unrelated to the actual
functionality of the `s3cli`, such as hitting the limit on VPCs that could be
created in an AWS account.

## Testing in AWS Lambda

[AWS Lambda](https://aws.amazon.com/lambda/) is an appealing alternative for our
testing purposes that addresses this issue. It completely eliminates the need to
ask for an entire networking stack and a EC2 instance in our CloudFormation
stack. This speeds up the time required to run CloudFormation for the testing
environment and (since it no longer relies on EC2) is completely immune to AWS
service limits.

Our use case also fits nicely within the intended usage of AWS Lambda in that it
interacts with other AWS services with an IAM role and that the tests take no
more than 10 seconds to run, meaning we only pay for 10 seconds of execution
time rather than paying for AWS EC2 costs.

One limitation of AWS Lambda is that the runtime code can only be one of three
choices: Node.js, Python, or Java. Although there is no support for BASH, we
can upload arbitrary assets as part of the deployment package and access these
assets in a read-only filesystem (but writing to /tmp is OK).

### Building the Deployment Package

For our approach, we decided to use a Python script as a harness to run a
compiled [Ginkgo](http://onsi.github.io/ginkgo/) test suite against our `s3cli`
binary and to grab the console output for the tests:

~~~python
import os
import logging
import subprocess

def test_runner_handler(event, context):
    os.environ['S3_CLI_PATH'] = './s3cli'
    os.environ['BUCKET_NAME'] = event['bucket_name']
    os.environ['REGION'] = event['region']
    os.environ['S3_HOST'] = event['s3_host']

    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    try:
        output = subprocess.check_output(['./integration.test', '-ginkgo.focus', 'AWS STANDARD IAM ROLE'],
                                env=os.environ, stderr=subprocess.STDOUT)
        logger.debug("INTEGRATION TEST OUTPUT:")
        logger.debug(output)
    except subprocess.CalledProcessError as e:
        logger.debug("INTEGRATION TEST EXITED WITH STATUS: " + str(e.returncode))
        logger.debug(e.output)
        raise
~~~

This Lambda function handler is fairly simple. First, we pull in environment
variables from `event`, which is passed in as part of invocations for this
Lambda function. We then set up the logger for the `STDOUT` and `STDERR` streams
in order to see the output of our test run. In order to specifically capture the
exit status from the test suite, we wrap the subprocess call in a `try` block
and print the log output in catching the `subprocess.CalledProcessError`.

Note that we refer to the `s3cli` and the compiled integration tests as
executables in the same working directory as the script.

Next, we compile our `s3cli` binary and integration test suite, specifying the
target architecture to be 64-bit Linux, as these binaries will be running as
part of the Lambda function:

~~~bash
git clone https://github.com/pivotal-golang/s3cli
cd s3cli
GOOS=linux GOARCH=amd64 go build s3cli/s3cli
GOOS=linux GOARCH=amd64 ginkgo build src/s3cli/integration
~~~

We finally package up the deployment in a zip file, specifying `-j` to strip the
directory path from the files to get all of the deployment assets in the same
directory.

~~~bash
zip -j deployment.zip src/s3cli/integration/integration.test s3cli lambda_function.py
~~~

### Preparing the AWS Environment

The only setup we do outside of the `s3cli` testing are the following:

  - Create a bucket in S3 for testing.
  - [Create an AWS IAM user][create_iam_user] with permissions to A) execute a
    basic Lambda Function, and B) read and write to/from CloudWatch logs. Follow
    [these instructions][policies] for attaching the managed policies.
  - [Create an AWS IAM service role][create_iam_role] that allows the AWS Lambda
    service to write to CloudWatch and access an S3 bucket with the following
    permissions: `s3::GetObject*`, `s3::PutObject*`, `s3::List*`,
    `s3::DeleteObject*`. When creating this role, select "AWS Lambda" to allow
    AWS Lambda to write to CloudWatch and S3. Make sure you save the ARN for
    this newly created role, as we will be using this value as the environment
    variable `IAM_ROLE_ARN` when creating our Lambda function.

The setup for our testing environment is automated with a CloudFormation
template, which you can find [here][cloudformation].

In the steps below, we will be using the [AWS Command Line
Interface](https://aws.amazon.com/cli/) for interacting with AWS. Configure your
AWS CLI with the access key ID and secret access key for the IAM user that you
have created as follows:

~~~bash
# example session
$ aws configure

AWS Access Key ID [****************AAAA]:
AWS Secret Access Key [****************AAAA]:
Default region name [us-east-1]:
Default output format [json]:
~~~

### Running the Lambda Function

Now that we have a zipped deployment package, we run the following AWS CLI
commands to create the Lambda function and invoke this function:

~~~bash
aws lambda create-function \
  --region us-east-1 \
  --function-name MY_LAMBDA_FUNCTION \
  --zip-file fileb://deployment.zip \
  --role ${IAM_ROLE_ARN} \
  --timeout 300 \
  --handler lambda_function.test_runner_handler \
  --runtime python2.7

aws lambda invoke \
  --invocation-type RequestResponse \
  --function-name MY_LAMBDA_FUNCTION \
  --region us-east-1 \
  --log-type Tail \
  --payload '{"region": "us-east-1", "bucket_name": "YOUR_BUCKET_NAME", "s3_host": "s3.amazonaws.com"}' \
  lambda.log
~~~

> Note: The `fileb://` above is [not a typo][fileb].

The output of the `aws lambda invoke` command will be a JSON document with
schema
~~~json
{
  "LogResult": "<BASE64 ENCODED OUTPUT TRUNCATED TO LAST 4KB>",
  "FunctionError": "(Unhandled|Handled)",
  "StatusCode": 200
}
~~~

We noticed a few quirks with testing with this approach.

First, this `aws lambda invoke` command does not exit with a non-zero status
when the Lambda function itself exits with an error. The existence of the
`FunctionError` key indicates whether or not the Lambda function encountered
errors, so we used `jq` to process the JSON and determine if our tests succeeded
or failed.

Additionally, our tests generate much more than 4KB of log data, so our initial
approach of decoding the Base64 encoded `LogResult` still yielded truncated
console output.

### Fetching the Full Log Output

Fortunately, all of the console output from our `logging.Logger` is sent
through AWS CloudWatch Logs if the IAM role we provide to the Lambda function is
allowed to create log groups, log streams, and log events.

To retrieve our CloudWatch logs, we determine the name of the first log stream
(for the first invocation of the Lambda function) for the log group that is
associated with our Lambda function. We then print the message for each log
event in the log stream to our own command line.

~~~bash
LOG_GROUP_NAME="/aws/lambda/MY_LAMBDA_FUNCTION"
LOG_STREAM_NAME=$(
  aws logs describe-log-streams --log-group-name=${LOG_GROUP_NAME} \
  | jq -r ".logStreams[0].logStreamName"
)
LOG_STREAM_EVENTS_JSON=$(
  aws logs get-log-events \
    --log-group-name=${LOG_GROUP_NAME} \
    --log-stream-name=${LOG_STREAM_NAME}
)

echo ${LOG_STREAM_EVENTS_JSON} | jq -r ".events | map(.message) | .[]"
~~~

## Summary

In order to test the IAM role capabilities of our `s3cli`, we wanted to find a
low-cost (in time and money) alternative to starting an EC2 networking stack and
EC2 instance. In this post, we've shown how to make use of AWS Lambda functions
to do just that.

[blobstore]:       http://bosh.io/docs/director-configure-blobstore.html
[iam_role]:        http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html
[create_iam_user]: http://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
[create_iam_role]: http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-service.html#roles-creatingrole-service-console
[policies]:        http://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_managed-using.html#attach-managed-policy-console
[cloudformation]:  https://github.com/pivotal-golang/s3cli/blob/4e8430386451979c65b38b234f34be4ea695c14d/ci/assets/cloudformation-s3cli-iam.template.json
[fileb]:           http://docs.aws.amazon.com/cli/latest/userguide/cli-using-param.html#cli-using-param-file-binary
