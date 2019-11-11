#!/bin/bash

if [[ $1 == spec/* ]]; then
  bundle exec bin/run-tests $@
else
  bash
fi
