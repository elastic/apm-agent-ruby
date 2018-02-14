#!/usr/bin/env bash
set -ex

local_vendor_path="$HOME/.cache/ruby-vendor"
container_vendor_path="/tmp/vendor/2.4.1"

mkdir -p $local_vendor_path

cd spec

docker build --pull --force-rm --build-arg RUBY_VERSION=ruby:2.4.1 -t lint:ruby .
docker run \
  -e LOCAL_USER_ID=$UID \
  -v "$local_vendor_path:$container_vendor_path" \
  -v "$(dirname $(pwd))":/app \
  --rm lint:ruby \
  /bin/bash -c "bundle install --path $container_vendor_path && rubocop"
