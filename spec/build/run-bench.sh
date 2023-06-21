#!/usr/bin/env bash

# Bash strict mode
set -exo pipefail

# Redirect cache and vendor dirs
export BUNDLE_CACHE_PATH=/tmp/cache
export BUNDLE_PATH=/tmp/vendor

# Create an isolate bench folder
mkdir -p /tmp/app
cp -r ${APP_PATH}/. /tmp/app/
cd /tmp/app

# Install project dependencies
bundle install

# Run benchmark and generate report
bench/benchmark.rb 2> "/app/spec/${REPORT_OUTPUT_NAME}.error" > "/app/spec/${REPORT_OUTPUT_NAME}.raw"
bench/report.rb < "/app/spec/${REPORT_OUTPUT_NAME}.raw" > "/app/spec/${REPORT_OUTPUT_NAME}.bulk"
