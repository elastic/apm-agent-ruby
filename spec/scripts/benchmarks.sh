#!/usr/bin/env bash
#
# Perform benchmarks for the given docker ruby image.
# NOTE:  It's required to be launched inside the root of the project.
#
# Usage: ./spec/scripts/benchmarks.sh jruby:9.1
#
set -exuo pipefail

if [ $# -lt 1 ]; then
  echo "Arguments missing"
  exit 2
fi

RUBY_IMAGE=${1}
VERSION=$(echo "${RUBY_IMAGE}" | cut -d":" -f2)

## Transform the versions like:
##  - docker.elastic.co/observability-ci/jruby:9.2-12-jdk to jruby-9.2-12-jdk
##  - jruby:9.1 to jruby-9.1
TRANSFORMED_VERSION=$(basename "${RUBY_IMAGE}" | sed "s#:#-#g")

local_vendor_path="$HOME/.cache/ruby-vendor"
container_vendor_path="/tmp/vendor/${TRANSFORMED_VERSION/ruby-/}"

mkdir -p "${local_vendor_path}"

cd spec

docker build --pull --force-rm --build-arg "RUBY_IMAGE=${RUBY_IMAGE}" -t "apm-agent-ruby:${VERSION}" .
RUBY_VERSION=${VERSION} docker-compose run \
  --user $UID \
  -e HOME=/app \
  -w /app \
  -e LOCAL_USER_ID=$UID \
  -v "$local_vendor_path:$container_vendor_path" \
  -v "$(dirname "$(pwd)"):/app" \
  --rm ruby_rspec \
  /bin/bash -c "set -x
    gem update --system
    gem install bundler
    bundle install --path $container_vendor_path
    bench/benchmark.rb 2> benchmark-${TRANSFORMED_VERSION}.error > benchmark-${TRANSFORMED_VERSION}.raw
    bench/report.rb < benchmark-${TRANSFORMED_VERSION}.raw > benchmark-${TRANSFORMED_VERSION}.bulk"

