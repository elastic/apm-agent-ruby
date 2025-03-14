---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/api.html
---

# API reference [api]

Although most usage is covered automatically, Elastic APM also has a public API that allows custom usage.


## Agent life cycle [agent-life-cycle]

Controlling when the agent starts and stops.


### `ElasticAPM.start` [api-agent-start]

To create and start an ElasticAPM agent use `ElasticAPM.start`:

```ruby
ElasticAPM.start(server_url: 'http://localhost:8200')
```

* `config`: An optional hash or `ElasticAPM::Config` instance with configuration options.  See [Configuration](/reference/configuration.md).

If you are using [Ruby on Rails](/reference/getting-started-rails.md) this is done automatically for you. If you choose not to require the `elastic_apm` gem and instead want to start the agent and hook into Rails manually, see [hooking into Rails explicitly](#rails-start). If you’re not using Rails, see [Getting started with Rack](/reference/getting-started-rack.md).


### `ElasticAPM.stop` [api-agent-stop]

Stop the currently running agent. Use this inside `at_exit` in your [Rack app](/reference/getting-started-rack.md) to gracefully shut down.


### `ElasticAPM.restart` [api-agent-restart]

If the agent is already running, this method will stop and start the agent.

If the agent is not already running, this method will start the agent.

A config can be passed to the method that will be used to start the agent. If the agent is already running and no config is passed to the `#restart` method, the running agent’s config will be used.


### `ElasticAPM.running?` [api-agent-running]

Returns whether the ElasticAPM Agent is currently running.


### `ElasticAPM.agent` [api-agent-agent]

Returns the currently running agent or nil.


## Instrumentation [_instrumentation]


### `ElasticAPM.current_transaction` [api-agent-current-transaction]

Returns the current `ElasticAPM::Transaction` or nil.


### `ElasticAPM.start_transaction` [api-agent-start_transaction]

Start a *transaction* eg. an incoming web request or a background job.

```ruby
# call with block
ElasticAPM.start_transaction('Name')
do_work # ...
ElasticAPM.end_transaction('result')
```

Arguments:

* `name`: A name for your transaction. Transactions are grouped by name. **Required**.
* `type`: A `type` for your transaction eg. `db.postgresql.sql`.
* `context:`: An optional [Context](#api-context) used to enrich the transaction with information about the current request.
* `trace_context:`: An optional `TraceContext` object for Distributed Tracing.

Returns the transaction.


### `ElasticAPM.end_transaction` [api-agent-end_transaction]

Ends the currently running transaction.

Arguments:

* `result`: A `String` result of the transaction, eg. `'success'`.


### `ElasticAPM.with_transaction` [api-agent-with_transaction]

Wrap a block in a Transaction, starting and ending around the block

```ruby
ElasticAPM.with_transaction 'Do things' do |transaction|
  do_work # ...

  transaction.result = 'success'
end
```

Arguments:

* `name`: A name for your transaction. Transactions are grouped by name. **Required**.
* `type`: A `type` for your transaction eg. `db.postgresql.sql`.
* `context:`: An optional [Context](#api-context) used to enrich the transaction with information about the current request.
* `trace_context:`: An optional `TraceContext` object for Distributed Tracing.
* `&block`: A block to wrap. Optionally yields the transaction.

Returns the return value of the given block.


### `ElasticAPM.start_span` [api-agent-start_span]

Start a new span.

```ruby
ElasticAPM.with_transaction 'Do things' do
  ElasticAPM.start_span 'Do one of the things'
  Database.query # ...
  ElasticAPM.end_span
end
```

Arguments:

* `name`: A name for your span. **Required**.
* `type`: The type of span eg. `db`.
* `subtype`: The subtype of span eg. `postgresql`.
* `action`: The action type of span eg. `connect` or `query`.
* `context`: An instance of `Span::Context`.
* `include_stacktrace`: Whether or not to collect a Stacktrace.
* `trace_context:`: An optional `TraceContext` object for Distributed Tracing.
* `parent:`: An optional parent transaction or span. Relevant when the span is created in another thread.
* `sync:`: An boolean to indicate whether the span is created synchronously or not.
* `&block`: An optional block to wrap with the span. The block is passed the span as an optional argument.

Returns the created span.

If you’d like to create an asynchronous span, you have to pass the parent `Span` or `Transaction` to the `start_span` method. You can also set the `sync` flag to `false`, if you’d like the span to be marked as asynchronous. This has no effect other than being queryable in Elasticsearch.

```ruby
transaction = ElasticAPM.current_transaction # or start one with `.start_transaction`
Thread.new do
  ElasticAPM.start_span(
    'job 1',
    parent: transaction,
    sync: false
  ) { Worker.perform }
  ElasticAPM.end_span
end
```


### `ElasticAPM.end_span` [api-agent-end_span]

Ends the currently running span.


### `ElasticAPM.with_span` [api-agent-with_span]

Wraps a block in a Span.

Arguments:

* `name`: A name for your span. **Required**.
* `type`: The type of span eg. `db`.
* `subtype`: The subtype of span eg. `postgresql`.
* `action`: The action type of span eg. `connect` or `query`.
* `context`: An instance of `Span::Context`.
* `include_stacktrace`: Whether or not to collect a Stacktrace.
* `trace_context:`: An optional `TraceContext` object for Distributed Tracing.
* `parent:`: An optional parent transaction or span. Relevant when the span is created in another thread.
* `sync:`: An boolean to indicate whether the span is created synchronously or not.
* `&block`: An optional block to wrap with the span. The block is passed the span as an optional argument.

Returns the return value of the given block.

If you’d like to create an asynchronous span, you have to pass the parent `Span` or `Transaction` to the `with_span` method. You can also set the `sync` flag to `false`, if you’d like the span to be marked as asynchronous.

```ruby
transaction = ElasticAPM.current_transaction # or start one with `.start_transaction`
Thread.new do
  ElasticAPM.with_span(
    'job 1',
    parent: transaction,
    sync: false
  ) { Worker.perform }
end
```


### `ElasticAPM.build_context` [api-agent-build-context]

Build a new *Context* from a Rack `env`.

A context provides information about the current request, response, user and more.

Arguments:

* `rack_env`: An instance of Rack::Env
* `for_type`: Symbol representing type of event, eg. `:transaction` or `error`

Returns the built context.


## Rails [rails-start]

Start the agent and hook into Rails manually. This is useful if you skip requiring the gem and using the `Railtie`.

```ruby
ElasticAPM::Rails.start(server_url: 'http://localhost:8200')
```


## Sinatra [sinatra-start]

Start the agent and hook into Sinatra.

```ruby
ElasticAPM::Sinatra.start(MySinatraApp, server_url: 'http://localhost:8200')
```


## Grape [grape-start]

Start the agent and hook into Grape.

```ruby
ElasticAPM::Grape.start(MyGrapeApp, server_url: 'http://localhost:8200')
```


## Errors [_errors]


### `ElasticAPM.report` [api-agent-report]

Send an `Exception` to Elastic APM.

If reported inside a transaction, the context from that will be added.

```ruby
begin
  do_a_thing_and_fail
rescue Exception => e
  ElasticAPM.report(e)
end
```

Arguments:

* `exception`: An instance of `Exception`. **Required**.
* `handled`: Whether the error was *handled* eg. wasn’t rescued and was represented to the user. Default: `true`.

Returns `[String]` ID of the generated `[ElasticAPM::Error]` object.


### `ElasticAPM.report_message` [api-agent-report-message]

Send a custom message to Elastic APM.

If reported inside a transaction, the context from that will be added.

```ruby
ElasticAPM.report_message('This should probably never happen?!')
```

Arguments:

* `message`: A custom error string. **Required**.

Returns `[String]` ID of the generated `[ElasticAPM::Error]` object.


## Context [api-context]


### `ElasticAPM.set_label` [api-agent-set-label]

Add a label to the current transaction. Labels are basic key-value pairs that are indexed in your Elasticsearch database and therefore searchable. The value can be a string, nil, numeric or boolean.

::::{tip}
Before using custom labels, ensure you understand the different types of [metadata](docs-content://solutions/observability/apps/metadata.md) that are available.
::::


```ruby
before_action do
  ElasticAPM.set_label(:company_id, current_user.company.id)
end
```

Arguments:

* `key`: A string key. Note that `.`, `*` or `"` will be converted to `_`.
* `value`: A value.

Returns the set `value`.

::::{warning}
Be aware that labels are indexed in Elasticsearch. Using too many unique keys will result in **https://www.elastic.co/blog/found-crash-elasticsearch#mapping-explosion[Mapping explosion]**.
::::



### `ElasticAPM.set_custom_context` [api-agent-set-custom-context]

Add custom context to the current transaction. Use this to further specify a context that will help you track or diagnose what’s going on inside your app.

::::{tip}
Before using custom context, ensure you understand the different types of [metadata](docs-content://solutions/observability/apps/metadata.md) that are available.
::::


If called several times during a transaction the custom context will be destructively merged with `merge!`.

```ruby
before_action do
  ElasticAPM.set_custom_context(company: current_user.company.to_h)
end
```

Arguments:

* `context`: A hash of JSON-compatible key-values. Can be nested.

Returns current custom context.


### `ElasticAPM.set_user` [api-agent-set-user]

Add the current user to the current transaction’s context.

Arguments:

* `user`: An object representing the user

Returns the given user


## Data [_data]


### `ElasticAPM.add_filter` [api-agent-add-filter]

Provide a filter to transform payloads before sending.

Arguments:

* `key`: A unique key identifying the filter
* `callable`: An object or proc (responds to `.call(payload)`)

Return the altered payload.

If `nil` is returned all subsequent filters will be skipped and the post request cancelled.

Example:

```ruby
ElasticAPM.add_filter(:filter_pings) do |payload|
  payload[:transactions]&.reject! do |t|
    t[:name] == 'PingsController#index'
  end
  payload
end
```


## Transaction [api-transaction]

`ElasticAPM.transaction` returns a `Transaction` (if the agent is running).


### Properties [_properties]

* `name`: String
* `type`: String
* `result`: String
* `outcome`: String (*unknown*, *success*, *failure*, nil)
* `trace_id`: String (readonly)


### `#sampled?` [api-transaction-sampled_]

Whether the transaction is *sampled* eg. it includes stacktraces for its spans.


### `#ensure_parent_id` [api-transaction-ensure_parent_id]

If the transaction does not have a parent-ID yet, calling this method generates a new ID, sets it as the parent-ID of this transaction, and returns it as a `String`.

This enables the correlation of the spans the JavaScript Real User Monitoring (RUM) agent creates for the initial page load with the transaction of the backend service.

If your service generates the HTML page dynamically, initializing the JavaScript RUM agent with the value of this method allows analyzing the time spent in the browser vs in the backend services.

To enable the JavaScript RUM agent, initialize the RUM agent with the Ruby agent’s current transaction:

```html
<script src="elastic-apm-js-base/dist/bundles/elastic-apm-js-base.umd.min.js"></script>
<script>
  var elasticApm = initApm({
    serviceName: '',
    serverUrl: 'http://localhost:8200',
    pageLoadTraceId: "<%= ElasticAPM.current_transaction&.trace_id %>",
    pageLoadSpanId: "<%= ElasticAPM.current_transaction&.ensure_parent_id %>",
    pageLoadSampled: <%= ElasticAPM.current_transaction&.sampled? %>
  })
</script>
```

See the [JavaScript RUM agent documentation](apm-agent-rum-js://reference/index.md) for more information.


## Span [api-span]


### Properties [_properties_2]

* `name`: String
* `type`: String
