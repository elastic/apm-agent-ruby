#!/usr/bin/env bash

# Bash strict mode
set -eo pipefail

# Create a new specific user
USER_ID=${LOCAL_USER_ID:-1001}
GROUP_ID=${LOCAL_GROUP_ID:-1001}
echo "Starting with UID: ${USER_ID}, GID: ${GROUP_ID} and APP_WORKDIR: ${APP_WORKDIR}"
[ $(getent group "${GROUP_ID}") ] || groupadd -g "${GROUP_ID}" user
useradd -u "${USER_ID}" --gid "${GROUP_ID}" -s "/bin/false" -d "${APP_WORKDIR}" user

# Create the app dir
mkdir -p "${APP_WORKDIR}"
chown -R "${USER_ID}:${GROUP_ID}" "${APP_WORKDIR}"

# Run command with lower priviledge
exec gosu ${USER_ID}:${GROUP_ID} "${@}"
