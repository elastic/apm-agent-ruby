# Base image
ARG RUBY_IMAGE
FROM ${RUBY_IMAGE}

# Env arguments
ENV \
  CI="1" \
  DEBIAN_FRONTEND=noninteractive \
  INCLUDE_COVERAGE="1" \
  GOSU_VERSION="1.16"

# Copy specific scripts
COPY build/ /usr/local/bin/

# Install dependencies and upgrade ruby system
RUN \
  apt-get update > /dev/null \
  && apt-get install -qq -y build-essential libpq-dev git tzdata \
  && update.sh

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
