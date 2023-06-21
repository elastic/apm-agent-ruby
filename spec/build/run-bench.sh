#!/usr/bin/env bash

# Bash strict mode
set -exo pipefail

# Check env vars
[ -z "${APP_PATH}" ] && echo "Environment variable 'APP_PATH' must be defined" && exit 1;
[ -z "${APP_WORKDIR}" ] && echo "Environment variable 'APP_WORKDIR' must be defined" && exit 1;
[ -z "${REPORT_OUTPUT_NAME}" ] && echo "Environment variable 'REPORT_OUTPUT_NAME' must be defined" && exit 1;

# Create an isolate bench folder
cp -r ${APP_PATH}/. "${APP_WORKDIR}"
cd "${APP_WORKDIR}"

# Install project dependencies
bundle install

# Run benchmark and generate report
bench/benchmark.rb 2> "${APP_PATH}/spec/${REPORT_OUTPUT_NAME}.error" > "${APP_PATH}/spec/${REPORT_OUTPUT_NAME}.raw"
bench/report.rb < "${APP_PATH}/spec/${REPORT_OUTPUT_NAME}.raw" > "${APP_PATH}/spec/${REPORT_OUTPUT_NAME}.bulk"
