#!/usr/bin/env bash
#
# Perform benchmarks for the given docker ruby image.
# NOTE:  It's required to be launched inside the root of the project.
#
# Usage: ./spec/scripts/benchmarks.sh jruby:9.1
#
set -exo pipefail

# Found current script directory
RELATIVE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Found project directory
BASE_PROJECT="$(dirname "$(dirname "${RELATIVE_DIR}")")"

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

mkdir -p "${local_vendor_path}"

cd "${BASE_PROJECT}/spec"

docker build --pull --force-rm --build-arg "RUBY_IMAGE=${IMAGE_NAME}" -t "apm-agent-ruby:${VERSION}" .

IMAGE_NAME=${IMAGE_NAME} RUBY_VERSION=${VERSION} USER_ID=${UID} \
  docker-compose -f ../docker-compose.yml run \
  -e HOME=/tmp \
  -e FRAMEWORK=rails \
  -w /app \
  -v "$local_vendor_path:$container_vendor_path" \
  -v "${BASE_PROJECT}:/app" \
  ${REFERENCE_REPO_FLAG} \
  --rm ruby_rspec \
  /bin/bash -c "set -x
    cp -rf ${container_vendor_path} /tmp/.vendor
    gem update --system
    gem install bundler
    bundle config --global set path '/tmp/.vendor'
    bundle install
    bench/benchmark.rb 2> /app/spec/${OUTPUT_NAME}.error > /app/spec/${OUTPUT_NAME}.raw
    bench/report.rb < /app/spec/${OUTPUT_NAME}.raw > /app/spec/${OUTPUT_NAME}.bulk"
