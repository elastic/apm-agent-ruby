#!/usr/bin/env bash

source /usr/local/bin/bash_standard_lib.sh

if [ -x "$(command -v docker)" ]; then
  grep "-" .ci/.jenkins_ruby.yml | grep -v 'observability-ci' | cut -d'-' -f2- | \
  while read -r version;
  do
      transformedName=${version/:/-}
      transformedVersion=$(echo "${version}" | cut -d":" -f2)
      imageName="apm-agent-ruby"
      registryImageName="docker.elastic.co/observability-ci/${imageName}:${transformedName}"
      if retry 2 docker pull "${registryImageName}"; then
        docker tag "${registryImageName}" "${imageName}:${transformedVersion}"
      else
        printf "Could not pull image %s\n" "${registryImageName}"
      fi
  done
fi
