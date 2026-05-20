ARG RUBY_IMAGE=ruby:3.3
FROM ${RUBY_IMAGE}

ARG USER_ID_GROUP
ARG FRAMEWORKS
ARG VENDOR_PATH
ARG BUNDLER_VERSION

# For tzdata
# ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
      && apt-get install -qq -y --no-install-recommends \
        build-essential libpq-dev git netbase \
      && rm -rf /var/lib/apt/lists/*

# Configure bundler and PATH
ENV LANG=C.UTF-8

ENV GEM_HOME=$VENDOR_PATH
ENV BUNDLE_PATH=$GEM_HOME \
  BUNDLE_JOBS=4 BUNDLE_RETRY=3
ENV BUNDLE_APP_CONFIG=$BUNDLE_PATH \
  BUNDLE_BIN=$BUNDLE_PATH/bin
ENV PATH=/app/bin:$BUNDLE_BIN:$PATH

ENV FRAMEWORKS $FRAMEWORKS

RUN mkdir -p $VENDOR_PATH \
      && chown -R $USER_ID_GROUP $VENDOR_PATH

# Upgrade RubyGems with a Ruby-version-compatible strategy and install Bundler.
RUN set -eux; \
      if ruby -e 'require "rubygems"; exit(Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2") ? 0 : 1)'; then \
        gem update --system 3.2.3; \
      else \
        gem update --system; \
      fi; \
      gem install bundler:$BUNDLER_VERSION

# Use unpatched, system version for more speed over less security.
# JRuby 9.2 reports Ruby 2.5, so pin nokogiri to the last supported release.
RUN set -eux; \
      if ruby -e 'require "rubygems"; exit(Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2") ? 0 : 1)'; then \
        gem install nokogiri -v 1.12.5 -- --use-system-libraries; \
      else \
        gem install nokogiri -- --use-system-libraries; \
      fi
# Rake is required to build http-parser on some jruby images
RUN gem install rake

RUN chown -R $USER_ID_GROUP $VENDOR_PATH
USER $USER_ID_GROUP

WORKDIR /app
