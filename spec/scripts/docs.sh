#!/usr/bin/env bash
set -e

cd spec

docker run \
  -v "$(dirname $(pwd))":/app \
  -w /app \
  --rm ruby:2.4.1
  /bin/bash -c "bundle && rake docs"
