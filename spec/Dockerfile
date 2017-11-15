ARG RUBY_IMAGE
FROM ${RUBY_IMAGE}

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs
RUN gem install bundler

WORKDIR /app
ADD . /app
