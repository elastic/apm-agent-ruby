#!/usr/bin/env bash

# Bash strict mode
set -eo pipefail

# Extract ruby version
RUBY_VERSION=$(ruby -e 'print "#{ RUBY_VERSION }\n"')

# Install specific dependencies for 2.5.x ruby versions
if [[ "${FRAMEWORK}" =~ ^rails-4\.([0-9]) ]]; then
  gem i "rubygems-update:~>2.7" --no-document
  update_rubygems --no-document
  gem i "bundler:~>1.17.3" --no-document
# Install specific dependencies for 2.4.x and 2.5.x ruby versions
elif [[ "${RUBY_VERSION}" =~ ^2\.(4|5).+ ]]; then
  gem i "rubygems-update:~>2.7" --no-document
  update_rubygems --no-document
  gem i "bundler:~>2.3.26" --no-document
else
  gem update --system --no-document
  gem i bundler --no-document
fi

# Install rake
gem i rake --no-document
