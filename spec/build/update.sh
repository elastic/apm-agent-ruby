#!/usr/bin/env bash

# Bash strict mode
set -eo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

# Found current script directory
RELATIVE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Found project directory
BASE_PROJECT="$(dirname "${RELATIVE_DIR}")"

# Extract ruby version
RUBY_VERSION=$(ruby -e 'print "#{ RUBY_VERSION }\n"')

if [[ "${RUBY_VERSION}" == "2.5"* ]]; then
  gem i "rubygems-update:~>2.7" --no-document
  update_rubygems --no-document
  gem i "bundler:~>2.3" --no-document
else
  gem update --system --no-document
  gem install bundler --no-document
fi

