#!/usr/bin/env bash
set -x

echo "Cleanup no longer needed"
exit 0

docker stop $(docker ps -a -q)
docker rm -v $(docker ps -q -a)
docker volume prune -f

exit 0
