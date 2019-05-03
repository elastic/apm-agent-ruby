ARG RUBY_IMAGE
FROM ${RUBY_IMAGE}

ENV CI "1"
ENV INCLUDE_COVERAGE "1"

RUN [ apt-get ] \
    && ( apt-get update -qq \
        && apt-get install -y build-essential libpq-dev git ) \
    || true

RUN [ yum ] \
    && ( yum update -y -q \
        && yum install -y git ) \
    || true

WORKDIR /app
