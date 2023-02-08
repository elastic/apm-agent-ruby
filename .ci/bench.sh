#!/usr/bin/env bash
set -eo pipefail

echo 'run my benchmark'

./spec/scripts/benchmarks.sh "ruby:2.6"
