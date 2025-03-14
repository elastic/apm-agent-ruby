---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/opentracing.html
---

# OpenTracing API [opentracing]

The Elastic APM OpenTracing bridge allows to create Elastic APM `Transactions` and `Spans`, using the OpenTracing API. In other words, it translates the calls to the OpenTracing API to Elastic APM and thus allows for reusing existing instrumentation.

The first span of a service will be converted to an Elastic APM `Transaction`, subsequent spans are mapped to Elastic APM `Span`.


## Operation Modes [operation-modes]

This bridge allows for different operation modes in combination with the Elastic APM Agent.

* Noop<br> If no Elastic APM agent is running, the bridge is in noop mode and does not actually record and report spans.
* Mix and Match<br> If you want to leverage the auto instrumentation of Elastic APM, but also want do create custom spans or use the OpenTracing API to add custom tags to the spans created by Elastic APM, you can just do that. The OpenTracing bridge and the standard Elastic APM API interact seamlessly.
* Manual instrumentation<br> If you don’t want Elastic APM to auto-instrument known frameworks, but instead only rely on manual instrumentation, disable the auto instrumentation setting the configuration option [`instrument`](/reference/configuration.md#config-instrument) to `false`.


## Getting started [getting-started]

Either `require 'elastic_apm/opentracing'` during the boot of your app or specify the `require:` argument to your `Gemfile`, eg. `gem 'elastic_apm', require: 'elastic_apm/opentracing'`.


## Set Elastic APM as the global tracer [init-tracer]

```ruby
::OpenTracing.global_tracer = ElasticAPM::OpenTracing::Tracer.new
```


## Elastic APM specific tags [elastic-apm-tags]

Elastic APM defines some tags which are not included in the OpenTracing API but are relevant in the context of Elastic APM.

* `type` - sets the type of the transaction, for example `request`, `ext` or `db`
* `user.id` - sets the user id, appears in the "User" tab in the transaction details in the Elastic APM app
* `user.email` - sets the user email, appears in the "User" tab in the transaction details in the Elastic APM app
* `user.username` - sets the user name, appears in the "User" tab in the transaction details in the Elastic APM app
* `result` - sets the result of the transaction. Overrides the default value of `success`. If the `error` tag is set to `true`, the default value is `error`.


## Caveats [unsupported]

Not all features of the OpenTracing API are supported.


### Context propagation [propagation]

This bridge only supports the format `OpenTracing::FORMAT_RACK`, using HTTP headers with capitalized names, prefixed with `HTTP_` as Rack does it.

`OpenTracing::FORMAT_BINARY` is currently not supported.


### Span References [references]

Currently, this bridge only supports `child_of` references. Other references, like `follows_from` are not supported yet.


### Baggage [baggage]

The `Span.set_baggage` method is not supported. Baggage items are dropped with a warning log message.


### Logs [opentracing-logs]

Logs are currently not supported.

