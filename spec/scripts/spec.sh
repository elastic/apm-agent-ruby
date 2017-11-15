#!/usr/bin/env bash
set -e

if [ $# -lt 2 ]; then
  echo "Arguments missing"
  exit 2
fi

cd spec

docker-compose build --pull --build-arg RUBY_IMAGE=${1/-/:} spec
docker-compose run \
  -e FRAMEWORK=$2 \
  -v "$(dirname $(pwd))":/app \
  --rm spec \
  /bin/bash -c "bundle && rake spec"
