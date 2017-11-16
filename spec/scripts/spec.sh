#!/usr/bin/env bash
set -ex

if [ $# -lt 2 ]; then
  echo "Arguments missing"
  exit 2
fi

local_vendor_path="$HOME/.cache/ruby-vendor"
container_vendor_path="/tmp/vendor/${1/ruby-/}"

mkdir -p $local_vendor_path

cd spec

docker build --pull --build-arg RUBY_VERSION=${1/-/:} -t spec .
docker run \
  -e LOCAL_USER_ID=$UID \
  -e FRAMEWORK=$2 \
  -v "$local_vendor_path:$container_vendor_path" \
  -v "$(dirname $(pwd))":/app \
  --rm spec \
  /bin/bash -c "bundle install --path $container_vendor_path && bundle exec rspec ${3:-spec}"
