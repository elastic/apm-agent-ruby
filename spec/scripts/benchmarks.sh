#!/usr/bin/env bash
#
# Perform benchmarks for the given docker ruby image.
# NOTE:  It's required to be launched inside the root of the project.
#
# Usage: ./spec/scripts/benchmarks.sh jruby:9.1
#

# Bash strict mode
set -exo pipefail

# Found current script directory
RELATIVE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Found project directory
BASE_PROJECT="$(dirname "$(dirname "${RELATIVE_DIR}")")"

# Arguments
IMAGE_NAME=${1:?"missing RUBY IMAGE NAME"}
VERSION=$(echo "${IMAGE_NAME}" | cut -d":" -f2)
REPORT_OUTPUT_NAME=${2:?"missing THE REPORT OUTPUT NAME"}

# Move in spec
cd "${BASE_PROJECT}/spec"

# Build custom container image
docker build --pull --force-rm --build-arg "RUBY_IMAGE=${IMAGE_NAME}" -t "apm-agent-ruby:${VERSION}" .

# Run bench
IMAGE_NAME="${IMAGE_NAME}" \
LOCAL_GROUP_ID="$(id -g)" \
LOCAL_USER_ID="$(id -u)" \
RUBY_VERSION="${VERSION}" \
  docker-compose -f ../docker-compose.yml run \
  -e REPORT_OUTPUT_NAME="${REPORT_OUTPUT_NAME}" \
  -v "${BASE_PROJECT}:/opt/app" \
  --rm ruby_rspec \
  run-bench.sh
