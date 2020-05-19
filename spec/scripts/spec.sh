#!/usr/bin/env bash
#
# Test the given docker ruby image and framework. Optionally to filter what test
# to be triggered otherwise all of them.
#
# NOTE: It's required to be launched inside the root of the project.
#
# Usage: ./spec/scripts/spec.sh jruby:9.1 sinatra-2.0
#
set -ex

if [ $# -lt 2 ]; then
  echo "Arguments missing"
  exit 2
fi

IMAGE_NAME=${1}
FRAMEWORK=${2}
TEST=${3}
VERSION=$(echo "${IMAGE_NAME}" | cut -d":" -f2)

cd spec

IMAGE_NAME=${IMAGE_NAME} RUBY_VERSION=${VERSION} USER_ID="$(id -u):$(id -g)" docker-compose up -d mongodb

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

docker build --build-arg "RUBY_IMAGE=${IMAGE_NAME}" -t "apm-agent-ruby:${VERSION}" .

IMAGE_NAME=${IMAGE_NAME} RUBY_VERSION=${VERSION} USER_ID="$(id -u):$(id -g)" \
  docker-compose -f ../docker-compose.yml run \
  -e FRAMEWORK="${FRAMEWORK}" \
  -e TEST_MATRIX="${FRAMEWORK}-${CLEAN_IMAGE_NAME}" \
  -e INCLUDE_SCHEMA_SPECS=1 \
  -e JDK_JAVA_OPTIONS="${JDK_JAVA_OPTIONS}" \
  -e JRUBY_OPTS="${JRUBY_OPTS}" \
  -e HOME="/tmp" \
  -v "$(dirname "$(pwd)"):/app" \
  -w /app \
  --rm ruby_rspec \
  /bin/bash -c "\
    gem install rake && \
    bundle update && \
    timeout -s9 15m bin/run-tests ${TEST}"
