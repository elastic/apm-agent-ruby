#!/usr/bin/env bash
set -e

if [ $# -lt 2 ]; then
  echo "Arguments missing"
  exit 2
fi

local_vendor_path="$HOME/.cache/ruby-vendor"
container_vendor_path="/tmp/vendor/${1/ruby-/}"

mkdir -p $local_vendor_path

cd spec

docker build --pull --force-rm --build-arg RUBY_VERSION=${1/-/:} -t apm-agent-ruby:${1} .
docker run \
  -e LOCAL_USER_ID=$UID \
  -e FRAMEWORK=$2 \
  -e INCLUDE_SCHEMA_SPECS=1 \
  -v "$local_vendor_path:$container_vendor_path" \
  -v "$(dirname $(pwd))":/app \
  --rm apm-agent-ruby:${1} \
  /bin/bash -c "bundle install --path $container_vendor_path && timeout -s9 5m bundle exec rspec ${3:-spec}"
