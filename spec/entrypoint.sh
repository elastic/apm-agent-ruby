#!/bin/bash

bundle

# If first arg is a spec path, run spec(s)
if [[ $1 == spec/* ]]; then
  bundle exec bin/run-tests $@
  exit 0
fi

# If no arguments, run all specs
if [[ $# == 0 ]]; then
  bundle exec bin/run-tests
  exit 0
fi

# Otherwise, run args as command
$@
