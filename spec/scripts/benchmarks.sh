#!/usr/bin/env bash
#
# Perform benchmarks for the given docker ruby image.
# NOTE:  It's required to be launched inside the root of the project.
#
# Usage: ./spec/scripts/benchmarks.sh jruby:9.1
#
set -exo pipefail

IMAGE_NAME=${1:?"missing RUBY IMAGE NAME"}
VERSION=$(echo "${IMAGE_NAME}" | cut -d":" -f2)
OUTPUT_NAME=${2:?"missing THE OUTPUT NAME"}
REFERENCE_REPO=${3}

if [ -z "${REFERENCE_REPO}" ] ; then
  REFERENCE_REPO_FLAG=""
else
  REFERENCE_REPO_FLAG="-v ${REFERENCE_REPO}:${REFERENCE_REPO}"
fi

local_vendor_path="$HOME/.cache/ruby-vendor"
container_vendor_path="/tmp/vendor/${OUTPUT_NAME/ruby-/}"
spec_path="$(dirname "$(pwd)")"

mkdir -p "${local_vendor_path}"

cd spec

docker build --pull --force-rm --build-arg "RUBY_IMAGE=${IMAGE_NAME}" -t "apm-agent-ruby:${VERSION}" .

IMAGE_NAME=${IMAGE_NAME} RUBY_VERSION=${VERSION} \
  docker-compose -f ../docker-compose.yml run \
  --user $UID \
  -e HOME=/tmp \
  -e FRAMEWORK=rails \
  -w /app \
  -e LOCAL_USER_ID=$UID \
  -v "$local_vendor_path:$container_vendor_path" \
  -v "${spec_path}:/app" \
  ${REFERENCE_REPO_FLAG} \
  --rm ruby_rspec \
  /bin/bash -c "set -x
    cp -rf ${container_vendor_path} /tmp/.vendor
    gem update --system
    gem install bundler
    bundle config --global set path '/tmp/.vendor'
    bundle install
    bench/benchmark.rb 2> ${spec_path}/${OUTPUT_NAME}.error > ${spec_path}/${OUTPUT_NAME}.raw
    bench/report.rb < ${spec_path}/${OUTPUT_NAME}.raw > ${spec_path}/${OUTPUT_NAME}.bulk"

