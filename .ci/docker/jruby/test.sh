#!/usr/bin/env bash
image=${1?image is required}
version=${2}

printf '\tTest %-30s %s\n' ${image}

if [ -n "$version" ] ; then
  test_name="Test java -version '$version'"
  docker run -t --rm $image java -version | grep -q "openjdk version \"$version\|1.$version" && printf '\t\t%-40s %s\n' "${test_name}" "PASSED" || printf '\t\t%-40s %s\n' "${test_name}" "FAILED"
fi

test_name="Test Hello World"
docker run -t --rm $image jruby -e "puts 'Hello World" | grep -q 'Hello World' && printf '\t\t%-40s %s\n' "${test_name}" "PASSED" || printf '\t\t%-40s %s\n' "${test_name}" "FAILED"
