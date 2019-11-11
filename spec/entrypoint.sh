#!/bin/bash
set -x
set -e

bundle install --path vendor/

$@
