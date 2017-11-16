ARG RUBY_VERSION
FROM ${RUBY_VERSION}

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs
RUN gem install bundler

WORKDIR /app
ADD . /app
