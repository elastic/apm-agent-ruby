#!/usr/bin/env bash
#
# Test the given docker ruby image. Optionally to filter what test
# to be triggered otherwise all of them.
#
# NOTE: It's required to be launched inside the root of the project.
#
# Usage:
#   All feature files: ./spec/scripts/features.sh jruby:9.1 sinatra-2.0
#   One feature file: ./spec/scripts/features.sh jruby:9.1 sinatra-2.0 "features/step_definitions/stepdefs.rb"
#

# Bash strict mode
set -exo pipefail

# Found current script directory
RELATIVE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Found project directory
BASE_PROJECT="$(dirname "$(dirname "${RELATIVE_DIR}")")"

if [ $# -lt 1 ]; then
  echo "Arguments missing"
  exit 2
fi

# Arguments
IMAGE_NAME="${1}"
TEST="${2}"
VERSION=$(echo "${IMAGE_NAME}" | cut -d":" -f2)

# Move in spec
cd "${BASE_PROJECT}/spec"

## Customise the docker container to enable the access to the internal of the jdk
## for the jruby docker images.
JDK_JAVA_OPTIONS=''
JRUBY_OPTS=''
if [[ $RUBY_IMAGE == *"jruby"* ]]; then
  # https://github.com/jruby/jruby/issues/4834#issuecomment-343371742
  JDK_JAVA_OPTIONS="--illegal-access=permit $(echo --add-opens=java.base/{java.lang,java.security,java.util,java.security.cert,java.util.zip,java.lang.reflect,java.util.regex,java.net,java.io,java.lang}=ALL-UNNAMED)"
  JRUBY_OPTS="--debug"
fi

CLEAN_IMAGE_NAME=$(echo $IMAGE_NAME | sed s/:/-/ )

# Build custom container image
docker build --pull --force-rm --build-arg "RUBY_IMAGE=${IMAGE_NAME}" -t "apm-agent-ruby:${VERSION}" .

# Start mongodb
docker compose up -d mongodb

# Run bdd tests
IMAGE_NAME="${IMAGE_NAME}" \
LOCAL_GROUP_ID="$(id -g)" \
LOCAL_USER_ID="$(id -u)" \
RUBY_VERSION="${VERSION}" \
  docker compose -f ../docker-compose.yml run \
  -e INCLUDE_SCHEMA_SPECS=1 \
  -e JDK_JAVA_OPTIONS="${JDK_JAVA_OPTIONS}" \
  -e JRUBY_OPTS="${JRUBY_OPTS}" \
  -e FRAMEWORKS="${FRAMEWORKS}" \
  -e TEST="${TEST}" \
  -v "${BASE_PROJECT}:/opt/app" \
  --rm ruby_rspec \
  run-bdd.sh
