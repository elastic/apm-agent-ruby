#!/usr/bin/env bash
set -ex

if [ $# -lt 2 ]; then
  echo "Arguments missing"
  exit 2
fi

cd spec

RUBY_IMAGE=${1/-/:}

docker-compose up -d mongodb

docker build --pull --build-arg RUBY_IMAGE=$RUBY_IMAGE -t apm-agent-ruby:$1 .
RUBY_VERSION=$1 docker-compose run \
  -e FRAMEWORK=$2 \
  -e INCLUDE_SCHEMA_SPECS=1 \
  -v "$(dirname $(pwd))":/app \
  --rm ruby_rspec \
  /bin/bash -c "\
    bundle install && \
    timeout -s9 5m bundle exec rspec -f progress -f JUnit -o spec/ruby-agent-junit.xml ${3:-spec}"
