#!/usr/bin/env bash

set -ex

RUBY_IMAGE=${1}
VERSION=$(echo "${RUBY_IMAGE}" | cut -d":" -f2)

cd spec
docker build --build-arg "RUBY_IMAGE=${RUBY_IMAGE}" -t "apm-agent-ruby:${VERSION}" .
