#!/usr/bin/env bash

export PR_NUMBER=$(jq -r '.number' $GITHUB_EVENT_PATH)
