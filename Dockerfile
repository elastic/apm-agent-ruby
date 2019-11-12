ARG RUBY_IMAGE
FROM ${RUBY_IMAGE}

ARG VENDOR_PATH
ARG BUNDLER_VERSION

# For tzdata
ENV DEBIAN_FRONTEND=noninteractive

RUN [ apt-get ] \
    && ( apt-get update -qq \
        && apt-get install -qq -y build-essential libpq-dev git tzdata) \
    || true

# Configure bundler and PATH
ENV LANG=C.UTF-8

ENV GEM_HOME=$VENDOR_PATH
ENV BUNDLE_PATH=$GEM_HOME \
  BUNDLE_JOBS=4 BUNDLE_RETRY=3
ENV BUNDLE_APP_CONFIG=$BUNDLE_PATH \
  BUNDLE_BIN=$BUNDLE_PATH/bin
ENV PATH=/app/bin:$BUNDLE_BIN:$PATH

# Upgrade RubyGems and install required Bundler version
RUN gem update --system && \
      gem install bundler:$BUNDLER_VERSION

# Use unpatched, system version for more speed over less security
RUN gem install nokogiri -- --use-system-libraries

WORKDIR /app
