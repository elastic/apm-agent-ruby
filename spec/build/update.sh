#!/usr/bin/env bash

# Bash strict mode
set -eo pipefail

# Extract ruby version
RUBY_VERSION=$(ruby -e 'print "#{ RUBY_VERSION }\n"')

# Install specific dependencies for rails 4.x versions
if [[ "${FRAMEWORK}" =~ ^rails-4\.([0-9]) ]]; then
  gem i "rubygems-update:~>2.7" --no-document
  update_rubygems --no-document
  gem i "bundler:~>1.17.3" --no-document
elif [[ "${RUBY_VERSION}" =~ ^2\.(6|7).+ ]]; then
  gem i "rubygems-update:~>3.4.0" --no-document
  update_rubygems --no-document
  gem i bundler --no-document
# Install specific dependencies for 2.4.x and 2.5.x ruby versions
elif [[ "${RUBY_VERSION}" =~ ^2\.(4|5).+ ]]; then
  gem i "rubygems-update:~>2.7" --no-document
  update_rubygems --no-document
  if ruby -e 'exit defined?(JRUBY_VERSION) ? 0 : 1'; then
    gem i "bundler:~>2.2.21" --no-document
    # Remove bundler versions >= 2.3 that may be pre-installed in the container's
    # system gems and would otherwise override the compatible 2.2.x version above.
    gem uninstall bundler --version ">=2.3.0" --executables --force --ignore-dependencies 2>/dev/null || true
  else
    gem i "bundler:~>2.3.26" --no-document
  fi
else
  gem update --system --no-document
  gem i bundler --no-document
fi

# Install rake
gem i rake --no-document
