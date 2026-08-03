# Base image
ARG RUBY_IMAGE=ruby:3.3
FROM ${RUBY_IMAGE}

# Env arguments
ENV \
  APP_WORKDIR="/var/app" \
  CI="1" \
  DEBIAN_FRONTEND="noninteractive" \
  INCLUDE_COVERAGE="1" \
  LANG=C.UTF-8 \
  GOSU_VERSION="1.16"

ENV \
  BUNDLE_BIN="$APP_WORKDIR/vendor/bin" \
  BUNDLE_CACHE_PATH="$APP_WORKDIR/cache" \
  BUNDLE_PATH="$APP_WORKDIR/vendor" \
  GEM_HOME="$APP_WORKDIR/vendor" \
  PATH="/opt/app/bin:$APP_WORKDIR/vendor/bin:$PATH"

# Copy specific scripts
COPY build/ /usr/local/bin/

# Reset to root user
USER root

# Install dependencies and upgrade ruby system
RUN set -eux; \
  apt-get update -qq || ( \
    find /etc/apt -name '*.list' -type f -print0 | xargs -0 sed -i \
      -e 's|deb.debian.org/debian|archive.debian.org/debian|g' \
      -e 's|security.debian.org/debian-security|archive.debian.org/debian-security|g'; \
    find /etc/apt -name '*.list' -type f -print0 | xargs -0 sed -i '/buster-updates/d'; \
    printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99no-check-valid; \
    apt-get -o Acquire::Check-Valid-Until=false update -qq \
  ); \
  apt-get install -qq -y --no-install-recommends build-essential curl gnupg dirmngr libpq-dev git tzdata; \
  rm -rf /var/lib/apt/lists/*

# Install gosu
RUN \
  curl -o /usr/local/bin/gosu -sSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture)" \
  && curl -o /usr/local/bin/gosu.asc -sSL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture).asc" \
  && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
  && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
  && rm /usr/local/bin/gosu.asc \
  && chmod +x /usr/local/bin/gosu

# Set workdir
WORKDIR /app

# Set specific entrypoint
ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
