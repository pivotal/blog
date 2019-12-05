#!/usr/bin/env bash

cf api 'https://api.run.pivotal.io'
cf auth --client-credentials
cf target -o $CF_ORG -s $CF_SPACE
