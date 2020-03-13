#!/usr/bin/env bash

docker build --build-arg "RUBY_IMAGE=ruby:2.7" --build-arg "VENDOR_PATH=vendor/2.7" --build-arg "BUNDLER_VERSION=2.0.2" --build-arg "USER_ID_GROUP=$(id -u):$(id -u)" -t "apm-agent-ruby:coverage" .
docker run  -e "TEST_MATRIX=nil" --mount type=bind,source="$(pwd)",target=/app apm-agent-ruby:coverage spec/scripts/coverage_entrypoint.sh