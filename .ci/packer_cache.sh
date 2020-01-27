#!/usr/bin/env bash

source /usr/local/bin/bash_standard_lib.sh

grep "-" .ci/.jenkins_ruby.yml | grep -v 'observability-ci' | cut -d'-' -f2- | \
while read -r version;
do
    transformedVersion=$(echo "${version}" | cut -d":" -f2)
    imageName="apm-agent-ruby:${transformedVersion}"
    registryImageName="docker.elastic.co/observability-ci/${imageName}"
    (retry 2 docker pull "${registryImageName}")
    docker tag "${registryImageName}" "${imageName}"
done
