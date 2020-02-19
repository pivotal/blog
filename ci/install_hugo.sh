#!/usr/bin/env bash

VERSION=0.64.1

mkdir /opt/hugo && cd /opt/hugo
wget https://github.com/gohugoio/hugo/releases/download/v${VERSION}/hugo_${VERSION}_Linux-64bit.tar.gz
tar xzf hugo_${VERSION}_Linux-64bit.tar.gz
