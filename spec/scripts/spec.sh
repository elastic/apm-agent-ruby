#!/usr/bin/env bash
set -ex

function cleanup {
  docker-compose down -v
}

trap cleanup EXIT

if [ $# -lt 2 ]; then
  echo "Arguments missing"
  exit 2
fi

local_vendor_path="$HOME/.cache/ruby-vendor"
container_vendor_path="/tmp/vendor/${1/ruby-/}"

mkdir -p $local_vendor_path

cd spec

RUBY_IMAGE=${1/-/:}

docker-compose up -d mongodb

docker build --pull --force-rm --build-arg RUBY_IMAGE=$RUBY_IMAGE -t apm-agent-ruby:$1 .
RUBY_VERSION=$1 docker-compose run \
  -e LOCAL_USER_ID=$UID \
  -e FRAMEWORK=$2 \
  -e INCLUDE_SCHEMA_SPECS=1 \
  -v "$local_vendor_path:$container_vendor_path" \
  -v "$(dirname $(pwd))":/app \
  --rm ruby_rspec \
  /bin/bash -c "bundle install --path $container_vendor_path && timeout -s9 5m bundle exec rspec ${3:-spec}"
