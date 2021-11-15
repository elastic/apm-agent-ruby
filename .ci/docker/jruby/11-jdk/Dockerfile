FROM openjdk:11-jdk

RUN apt-get update \
    && apt-get install -y libc6-dev --no-install-recommends \
    && apt-get install -y gcc \
    && rm -rf /var/lib/apt/lists/*

ENV JRUBY_VERSION 9.2.16.0
ENV JRUBY_SHA256 9199707712c683c525252ccb1de5cb8e75f53b790c5b57a18f6367039ec79553

RUN mkdir -p /opt/jruby \
    && curl -fSL https://repo1.maven.org/maven2/org/jruby/jruby-dist/${JRUBY_VERSION}/jruby-dist-${JRUBY_VERSION}-bin.tar.gz -o /tmp/jruby.tar.gz \
    && echo "$JRUBY_SHA256 */tmp/jruby.tar.gz" | sha256sum -c - \
    && tar -zx --strip-components=1 -f /tmp/jruby.tar.gz -C /opt/jruby \
    && update-alternatives --install /usr/local/bin/ruby ruby /opt/jruby/bin/jruby 1

# set the jruby binaries in the path
ENV PATH /opt/jruby/bin:$PATH

# skip installing gem documentation
RUN mkdir -p /opt/jruby/etc \
    && { \
        echo 'install: --no-document'; \
        echo 'update: --no-document'; \
    } >> /opt/jruby/etc/gemrc

# install bundler, gem requires bash to work
RUN gem install bundler rake net-telnet xmlrpc tzinfo-data

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_BIN="$GEM_HOME/bin" \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
    && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

CMD [ "irb" ]
