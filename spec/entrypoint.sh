#!/bin/bash

# Set bundle path scoped by ruby image
export BUNDLE_PATH=$GEM_HOME/$(echo $RUBY_IMAGE | sed -e s/:/-/g)
export BUNDLE_JOBS=4
export BUNDLE_RETRY=3
export BUNDLE_APP_CONFIG=$BUNDLE_PATH
export BUNDLE_BIN=$BUNDLE_PATH/bin
export PATH=/app/bin:$BUNDLE_BIN:$PATH

# If first arg is a spec path, run spec(s)
if [[ $1 == spec/* ]]; then
  bundle exec bin/run-tests $@
  exit 0
fi

$@
