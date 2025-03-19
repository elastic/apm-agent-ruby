---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/master/logs.html
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/log-correlation.html
---

# Logs [logs]

Elastic Ruby APM Agent provides the following log features:

* [Log correlation](#log-correlation-ids): Automatically inject correlation IDs that allow navigation between logs, traces and services.
* [Log reformatting (experimental)](#log-reformatting): Automatically reformat plaintext logs in [ECS logging](ecs-logging://reference/intro.md) format.

Those features are part of [Application log ingestion strategies](docs-content://solutions/observability/logs/stream-application-logs.md).

The [`ecs-logging-ruby`](ecs-logging-ruby://reference/index.md) library can also be used to format logs in the [ECS logging](ecs-logging://reference/intro.md) format without an APM agent. When deployed with the Ruby APM agent, the agent will provide [log correlation](#log-correlation-ids) IDs.


## Log correlation [log-correlation-ids]

[Log correlation](docs-content://solutions/observability/apps/logs.md) allows you to navigate to all logs belonging to a particular trace and vice-versa: for a specific log, see in which context it has been logged and which parameters the user provided.

Trace/log correlation can be set up in three different ways.


### Rails TaggedLogging [rails-tagged-logging]

Rails applications configured with an `ActiveSupport::TaggedLogging` logger can append the correlation IDs to log output. For example in your `config/environments/production.rb` file, add the following:

```ruby
config.log_tags = [ :request_id, proc { ElasticAPM.log_ids } ]

# Logs will then include the correlation IDs:
#
# [transaction.id=c1ae84c8642891eb trace.id=b899fc7915e801b7558e336e4952bafe] Started GET "/" for 127.0.0.1 at 2019-09-16 11:28:46 +0200
# [transaction.id=c1ae84c8642891eb trace.id=b899fc7915e801b7558e336e4952bafe] Processing by ApplicationController#index as HTML
# [transaction.id=c1ae84c8642891eb trace.id=b899fc7915e801b7558e336e4952bafe]   Rendering text template
# [transaction.id=c1ae84c8642891eb trace.id=b899fc7915e801b7558e336e4952bafe]   Rendered text template (Duration: 0.1ms | Allocations: 17)
# [transaction.id=c1ae84c8642891eb trace.id=b899fc7915e801b7558e336e4952bafe] Completed 200 OK in 1ms (Views: 0.4ms | Allocations: 171)
```

**Note:** Because of the order in which Rails computes the tags for logs and executes the request, the span id might not be included. Consider using `Lograge` instead, as the timing of its hooks allow the span id to be captured in logs.


### Lograge [lograge]

With `lograge` enabled and set up in your Rails application, modify the `custom_options` block in the Rails environment configuration file. The returned `Hash` will be included in the structured Lograge logs.

```ruby
config.lograge.custom_options = lambda do |event|
  ElasticAPM.log_ids do |transaction_id, span_id, trace_id|
    { :'transaction.id' => transaction_id,
      :'span.id' => span_id,
      :'trace.id' => trace_id }
  end
end

# Logs will then include the correlation IDs:
#
# I, [2019-09-16T11:59:05.439602 #8674]  INFO -- : method=GET path=/ format=html controller=ApplicationController action=index status=200 duration=0.36 view=0.20 transaction.id=56a9186a9257aa08 span.id=8e84a786ab0abbb2 trace.id=1bbab8ac4c7c9584f53eb882ff0dfdd8
```

You can also nest the ids in a separate document as in the following example:

```ruby
config.lograge.custom_options = lambda do |event|
  ElasticAPM.log_ids do |transaction_id, span_id, trace_id|
    { elastic_apm: { :'transaction.id' => transaction_id,
                     :'span.id' => span_id,
                     :'trace.id' => trace_id } }
  end
end

# Logs will then include the correlation IDs in a separate document:
#
# I, [2019-09-16T13:39:35.962603 #9327]  INFO -- : method=GET path=/ format=html controller=ApplicationController action=index status=200 duration=0.37 view=0.20 elastic_apm={:transaction_id=>"2fb84f5d0c48a296", :span_id=>"2e5c5a7c85f83be7", :trace_id=>"43e1941c4a6fff343a4e018ff7b92000"}
```


### Manually formatting logs [manually-formatting-logs]

You can access the correlation ids directly and add them through the log formatter.

```ruby
require 'elastic_apm'
require 'logger'

logger = Logger.new(STDOUT)
logger.progname = 'TestRubyApp'
logger.formatter  = proc do |severity, datetime, progname, msg|
  "[#{datetime}][#{progname}][#{severity}][#{ElasticAPM.log_ids}] #{msg}\n"
end

# Logs will then include the correlation IDs:
#
# [2019-09-16 11:54:59 +0200][RailsTestApp][INFO][transaction.id=3b92edcccc0a6d1e trace.id=1275686e35de91f776557637e799651e] Started GET "/" for 127.0.0.1 at 2019-09-16 11:54:59 +0200
# [2019-09-16 11:54:59 +0200][RailsTestApp][INFO][transaction.id=3b92edcccc0a6d1e trace.id=1275686e35de91f776557637e799651e] Processing by ApplicationController#index as HTML
# [2019-09-16 11:54:59 +0200][RailsTestApp][INFO][transaction.id=3b92edcccc0a6d1e span.id=3bde4e9c85ab359c trace.id=1275686e35de91f776557637e799651e]   Rendering text template
# [2019-09-16 11:54:59 +0200][RailsTestApp][INFO][transaction.id=3b92edcccc0a6d1e span.id=f3d7e32f176d4c93 trace.id=1275686e35de91f776557637e799651e]   Rendered text template (Duration: 0.1ms | Allocations: 17)
# [2019-09-16 11:54:59 +0200][RailsTestApp][INFO][transaction.id=3b92edcccc0a6d1e span.id=3bde4e9c85ab359c trace.id=1275686e35de91f776557637e799651e] Completed 200 OK in 1ms (Views: 0.3ms | Allocations: 187)
```


### Extracting trace IDs from the logs [_extracting_trace_ids_from_the_logs]

For log correlation to work, the trace IDs must be extracted from the log message and stored in separate fields in the Elasticsearch document. There are many ways to achieve this, for example by using ingest node and defining a pipeline with a grok processor. You can extract the trace id from the Lograge output generated above like this:

```json
PUT _ingest/pipeline/extract_trace_id
{
  "description": "Extract trace id from Lograge logs",
  "processors": [
    {
      "grok": {
        "field": "message",
        "patterns": ["%{TIME}.*\\| [A-Z]\\, \\[%{TIMESTAMP_ISO8601}.*\\]  %{LOGLEVEL:log.level} [-]{2} \\: \\[[0-9A-Fa-f\\-]{36}\\] \\{.*\\\"trace\\.id\\\"\\:\\\"%{TRACE_ID:trace.id}.*\\}"],
        "pattern_definitions": { "TRACE_ID": "[0-9A-Fa-f]{32}" }
      }
    }
  ]
}
```

Please see [Observability integrations](docs-content://solutions/observability/apps/logs.md) for more information.


## Log reformatting (experimental) [log-reformatting]

Log reformatting is controlled by the [`log_ecs_reformatting`](/reference/configuration.md#config-log-ecs-formatting) configuration option, and is disabled by default.

The reformatted logs will include both the [trace and service correlation](#log-correlation-ids) IDs.
