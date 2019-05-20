#!/usr/bin/env bash
#
# Test the given docker ruby image and framework. Optionally to filter what test
# to be triggered otherwise all of them.
#
# NOTE: It's required to be launched inside the root of the project.
#
# Usage: ./spec/scripts/spec.sh jruby:9.1 sinatra-2.0
#
set -ex

if [ $# -lt 2 ]; then
  echo "Arguments missing"
  exit 2
fi

RUBY_IMAGE=${1}
FRAMEWORK=${2}
TEST=${3:-spec}
VERSION=$(echo "${RUBY_IMAGE}" | cut -d":" -f2)

cd spec

docker-compose up -d mongodb

docker build --pull --build-arg "RUBY_IMAGE=${RUBY_IMAGE}" -t "apm-agent-ruby:${VERSION}" .
RUBY_VERSION=${VERSION} docker-compose run \
  -e FRAMEWORK="${FRAMEWORK}" \
  -e INCLUDE_SCHEMA_SPECS=1 \
  -v "$(dirname "$(pwd)"):/app" \
  --rm ruby_rspec \
  /bin/bash -c "\
    bundle install && \
    timeout -s9 5m bundle exec rspec -f progress -f JUnit -o spec/ruby-agent-junit.xml ${TEST}"
