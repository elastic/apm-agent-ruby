#!/usr/bin/env bash
set -e

exit 0

if [ $# -lt 1 ]; then
  echo "Arguments missing"
  exit 2
fi

local_vendor_path="$HOME/.cache/ruby-vendor"
container_vendor_path="/tmp/vendor/${1/ruby-/}"

mkdir -p $local_vendor_path

cd spec

RUBY_IMAGE=${1/-/:}

docker build --pull --force-rm --build-arg RUBY_IMAGE=$RUBY_IMAGE -t apm-agent-ruby:$1 .
RUBY_VERSION=$1 docker-compose run \
  -e LOCAL_USER_ID=$UID \
  -e CLOUD_ADDR=$CLOUD_ADDR \
  -v "$local_vendor_path:$container_vendor_path" \
  -v "$(dirname $(pwd))":/app \
  --rm ruby_rspec \
  /bin/bash -c "bundle install --path $container_vendor_path && timeout 5m bench/benchmark.rb | bench/report.rb"
