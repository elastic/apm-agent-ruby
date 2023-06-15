#!/usr/bin/env bash

set -x

export BUNDLE_CACHE_PATH=/tmp/.cache
export BUNDLE_PATH=/tmp/.vendor

cp -rf ${VENDOR_PATH} /tmp/.vendor
bundle install
bench/benchmark.rb 2> /app/spec/${REPORT_OUTPUT_NAME}.error > /app/spec/${REPORT_OUTPUT_NAME}.raw
bench/report.rb < /app/spec/${REPORT_OUTPUT_NAME}.raw > /app/spec/${REPORT_OUTPUT_NAME}.bulk"
