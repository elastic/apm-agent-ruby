#!/usr/bin/env bash

source /usr/local/bin/bash_standard_lib.sh

grep "-" .ci/.jenkins_ruby.yml | cut -d'-' -f2- | \
while read -r version;
do
    imageName="apm-agent-ruby:${version}"
    registryImageName="docker.elastic.co/observability-ci/${imageName}"
    (retry 2 docker pull "${registryImageName}")
    docker tag "${registryImageName}" "${imageName}"
done
