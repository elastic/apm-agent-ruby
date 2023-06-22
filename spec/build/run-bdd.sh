#!/usr/bin/env bash

# Bash strict mode
set -exo pipefail

# Check env vars
[ -z "${APP_PATH}" ] && echo "Environment variable 'APP_PATH' must be defined" && exit 1;
[ -z "${APP_WORKDIR}" ] && echo "Environment variable 'APP_PATH' must be defined" && exit 1;

# Create an isolate bench folder
cp -r ${APP_PATH}/. "${APP_WORKDIR}"
cd "${APP_WORKDIR}"

# Install project dependencies
bundle install

# Run tests
timeout -s9 15m "${APP_WORKDIR}/bin/run-bdd" "${TEST:-}"
