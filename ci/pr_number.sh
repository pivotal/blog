#!/usr/bin/env bash

PR_NUMBER=$(jq -r '.number' $GITHUB_EVENT_PATH)
