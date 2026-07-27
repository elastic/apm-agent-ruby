#!/bin/bash
set -x

if ruby -e 'exit Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.5") ? 0 : 1'; then
  # The RubyGems shim-based `bundle _x.y.z_` form can break with custom BUNDLE_BIN paths.
  # Force a single compatible bundler version for Ruby 2.4 and use plain `bundle`.
  gem uninstall bundler -v '>= 2' -aIx || true
  gem list -i bundler -v 1.17.3 >/dev/null || gem install bundler -v 1.17.3
  BUNDLE_CMD='bundle'
else
  BUNDLE_CMD='bundle'
fi

$BUNDLE_CMD check || (rm -f Gemfile.lock && $BUNDLE_CMD)

# If first arg is a spec path, run spec(s)
if [[ $1 == spec/* ]]; then
  $BUNDLE_CMD exec bin/run-tests $@
  exit $?
fi

# If no arguments, run all specs
if [[ $# == 0 ]]; then
  $BUNDLE_CMD exec bin/run-tests
  exit $?
fi

# Otherwise, run args as command
$@
