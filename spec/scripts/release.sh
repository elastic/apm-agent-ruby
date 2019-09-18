#!/usr/bin/env bash
#
# Release the gem with the given docker ruby image.
#
# NOTE: It's required to be launched inside the root of the project.
#
# Usage: ./spec/scripts/release.sh ruby:2
#
set -ex

if [ $# -lt 1 ]; then
  echo "Arguments missing"
  exit 2
fi

RUBY_IMAGE=${1}
VERSION=$(echo "${RUBY_IMAGE}" | cut -d":" -f2)

cd spec

docker build --pull --build-arg "RUBY_IMAGE=${RUBY_IMAGE}" -t "apm-agent-ruby:${VERSION}" .
RUBY_VERSION=${VERSION} docker-compose run \
  -e INCLUDE_SCHEMA_SPECS=1 \
  -e HOME=/app \
  -v "$(dirname "$(pwd)"):/app" \
  --rm ruby_rspec \
  /bin/bash -c "\
    bundle install && rake release"
