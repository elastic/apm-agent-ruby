---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/supported-technologies.html
applies_to:
  stack:
  serverless:
    observability:
  product:
    apm_agent_ruby: ga
---

# Supported technologies [supported-technologies]

The Elastic APM Ruby Agent has built-in support for many frameworks and libraries. Generally, we want to support all of the most popular libraries. If your favorite is missing, feel free to request it in an issue, or better yet, create a pull request.


## Ruby [supported-technologies-ruby]

We follow Ruby’s own maintenance policy and officially support all currently maintained versions per [Ruby Maintenance Branches](https://www.ruby-lang.org/en/downloads/branches/).


## Web Frameworks and Libraries [supported-technologies-web]

We have automatic support for Ruby on Rails and all Rack compatible web frameworks.

We test against all supported minor versions of Rails, Sinatra, and Grape.


### Ruby on Rails [supported-technologies-rails]

We currently support Rails >= 4.2 <= 8.1.1. This follows Rails' own [Security policy](https://rubyonrails.org/security/).

See [Getting started with Rails](/reference/getting-started-rails.md).


### Sinatra [supported-technologies-sinatra]

We currently support Sinatra >= 1.0 <= 4.2.1.

See [Getting started with Rack](/reference/getting-started-rack.md).


### Grape [supported-technologies-grape]

We currently support Grape >= 1.2 <= 3.0.1.

See [Grape example](/reference/getting-started-rack.md#getting-started-grape).


## Databases [supported-technologies-databases]

We automatically instrument database actions using:

* ActiveRecord (>= 4.2 <= 8.1.1)
* DynamoDB (>= 1.0 <= 1.158.0)
* Elasticsearch (>= 0.9 <= 9.2.0)
* Mongo (>= 2.1 <= 2.22.0)
* Redis (>= 3.1 <= 5.4.1)
* Sequel (>= 4.35 <= 5.100.0)


## External HTTP requests [supported-technologies-http]

We automatically instrument and add support for distributed tracing to external requests using these libraries:

* `net/http`
* Http.rb (>= 0.6 <= 0.16.1)
* Faraday (>= 0.2.1 <= 2.14.0)

**Note:** These libraries usually assume `localhost` if no `Host` is specified, so the agent does as well.


## Background Processing [supported-technologies-backgroud-processing]

We automatically instrument background processing using:

* DelayedJob (<= 4.1.11)
* Sidekiq (<= 8.1.0)
* Shoryuken (<= 6.2.1)
* Sneakers (2.12.0) (Experimental, see [#676](https://github.com/elastic/apm-agent-ruby/pull/676))
* Resque (>= 2.0.0 <= 2.7.0)
* SuckerPunch (>= 2.0.0 <= 3.3.0)


## Resque [supported-technologies-resque]

To make the agent work with Resque, you need to require `elastic_apm/resque` before you boot your Resque worker process.

For example in your `Rakefile`:

```ruby
require 'resque'
require 'elastic_apm'
require 'elastic_apm/resque'
```

When you start Resque, you should see a series of messages like the following in the Resque logs:

```ruby
I, [XXX #81227]  INFO -- : Starting worker main
D, [XXX #81227] DEBUG -- : Registered signals
I, [XXX #81227]  INFO -- : Running before_first_fork hooks
D, [XXX #81227] DEBUG -- : Starting ElasticAPM agent
```

Also be sure to set the Resque environment variable `RUN_AT_EXIT_HOOKS` to `true`. Otherwise, the fork may be terminated before the agent has a chance to send all the fork’s events to the APM server.


## SuckerPunch [supported-technologies-sucker-punch]

Asynchronously executed jobs in SuckerPunch are automatically instrumented.

Note that errors raised in the user-defined `JobClass#perform` method will be first handled by the SuckerPunch exception handler before being handled by the agent. The handler is accessed/set via `SuckerPunch.exception_handler` in version 2.0. The agent transaction will be marked as successful unless you re-raise the error in the exception handler. You can also explicitly report the error via [`ElasticAPM.report`](/reference/api-reference.md#api-agent-report) in a custom SuckerPunch exception handler.


## gRPC [supported-technologies-grpc]

We automatically instrument gRPC using the `grpc` gem. Note that this is experimental, as the `grpc` gem’s support for `Interceptors` is experimental as of version 1.27.0.

To instrument a client, add the `ElasticAPM::GRPC::ClientInterceptor` as an `interceptor` at Stub creation.

```ruby
Helloworld::Greeter::Stub.new(
  'localhost:50051',
  interceptors: [ElasticAPM::GRPC::ClientInterceptor.new]
)
```

To instrument a server, add the `ElasticAPM::GRPC::ServerInterceptor`.

```ruby
GRPC::RpcServer.new(interceptors: [ElasticAPM::GRPC::ServerInterceptor.new])
```

