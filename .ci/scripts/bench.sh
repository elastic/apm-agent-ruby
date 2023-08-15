#!/usr/bin/env bash

# Bash strict mode
set -eo pipefail

# Found current script directory
RELATIVE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Found project directory
BASE_PROJECT="$(dirname "$(dirname "${RELATIVE_DIR}")")"

## Buildkite specific configuration
if [ "$CI" == "true" ] ; then
  # If HOME is not set then use the Buildkite workspace
  # that's normally happening when running in the CI
  # owned by Elastic.
  if [ -z "$HOME" ] ; then
    HOME=$BUILDKITE_BUILD_CHECKOUT_PATH
    export HOME
  fi

  # required when running the benchmark
  PATH=$PATH:$HOME/.local/bin
  export PATH

  echo 'Docker login is done in the Buildkite hooks'
fi

# It does not fail so it runs for every single version and then we report the error at the end.
set +e
status=0

for VERSION in "ruby:3.1" "ruby:3.0" "ruby:2.7" "ruby:2.6" "jruby:9.2" ; do
    ## Transform the versions like:
    ## jruby:9.1 to jruby-9.1
  echo "--- Benchmark for :ruby: ${VERSION}"
  OUTPUT_NAME=benchmark-$(echo "${VERSION//:/-}")

  # TBC, maybe a timeout could help so it can run the other versions?
  ${BASE_PROJECT}/spec/scripts/benchmarks.sh "${VERSION}" "${OUTPUT_NAME}"

  # Gather error if any
  if [ $? -gt 0 ] ; then
    status=1
  fi

  # Then we ship the data using the helper
  sendBenchmark "${ES_USER_SECRET}" "${ES_PASS_SECRET}" "${ES_URL_SECRET}" "${BASE_PROJECT}/spec/${OUTPUT_NAME}.bulk"
done

# Report status
exit $status
