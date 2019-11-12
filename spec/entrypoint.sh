#!/bin/bash
set -x

bundle || $(rm Gemfile.lock && bundle)

# If first arg is a spec path, run spec(s)
if [[ $1 == spec/* ]]; then
  bundle exec bin/run-tests $@
  exit $?
fi

# If no arguments, run all specs
if [[ $# == 0 ]]; then
  bundle exec bin/run-tests
  exit $?
fi

# Otherwise, run args as command
$@
