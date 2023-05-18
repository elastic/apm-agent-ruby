#!/usr/bin/env bash
set -exo pipefail

## Buildkite specific configuration
if [ "$CI" == "true" ] ; then
	# If HOME is not set then use the Buildkite workspace
	# that's normally happening when running in the CI
	# owned by Elastic.
	if [ -z "$HOME" ] ; then
		HOME=$BUILDKITE_BUILD_CHECKOUT_PATH
		export HOME
	fi

	# required when running the benchmark
	PATH=$PATH:$HOME/.local/bin
	export PATH

	echo 'Docker login is done in the Buildkite hooks'
fi

# It does not fail so it runs for every single version and then we report the error at the end.
set +e
status=0

for VERSION in "ruby:3.1" "ruby:3.0" "ruby:2.7" "ruby:2.6" "jruby:9.2" ; do
    ## Transform the versions like:
    ## jruby:9.1 to jruby-9.1
	OUTPUT_NAME=benchmark-$(echo "${VERSION//:/-}")

	# TBC, maybe a timeout could help so it can run the other versions?
	# APM_AGENT_GO* env variables are provided by the Buildkite hooks.
	./spec/scripts/benchmarks.sh "${VERSION}" "${OUTPUT_NAME}" "$(pwd)"

	# Gather error if any
	if [ $? -gt 0 ] ; then
		status=1
	fi

	# Then we ship the data using the helper
	echo "TBC: sendBenchmarks(file: \"{OUTPUT_NAME}.bulk\", index: \"benchmark-ruby\", archive: true)"
done

# Report status
exit $status
