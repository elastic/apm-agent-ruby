---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/configuration.html
---

# Configuration [configuration]

There are several ways to configure how Elastic APM behaves. We recommend using a `config/elastic_apm.yml` file:

```yaml
server_url: 'http://localhost:8200'
secret_token: <%= ENV["VERY_SECRET_TOKEN"] %>
```

Some options can be set with `ENV` variables. When using this method, strings are split by comma, e.g., `ELASTIC_APM_SANITIZE_FIELD_NAMES="a,b" # => [/a/, /b/]`.


## Configuration precedence [configuration-precedence]

Options are applied in the following order (last one wins):

1. Defaults
2. Arguments to `ElasticAPM.start` / `Config.new`
3. Config file, e.g., `config/elastic_apm.yml`
4. Environment variables
5. [Central configuration](docs-content://solutions/observability/apps/apm-agent-central-configuration.md) (supported options are marked with [![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration))


## Dynamic configuration [dynamic-configuration]

Configuration options marked with the ![dynamic config](../images/dynamic-config.svg "") badge can be changed at runtime when set from a supported source.

The Agent supports [Central configuration](docs-content://solutions/observability/apps/apm-agent-central-configuration.md), which allows you to fine-tune certain configurations via the APM app. This feature is enabled in the Agent by default, with [`central_config`](#config-central-config).


## Ruby on Rails [_ruby_on_rails]

When using Rails, it’s possible to specify options inside `config/application.rb`:

```ruby
# config/application.rb
config.elastic_apm.service_name = 'MyApp'
```


## Sinatra and Rack [_sinatra_and_rack]

When using Sinatra and Rack, you can configure when starting the agent:

```ruby
# config.ru or similar
ElasticAPM.start(
  app: MyApp,
  service_name: 'SomeOtherName'
)
```

Alternatively, use the `ElasticAPM::Sinatra.start` API:

```ruby
# config.ru or similar
ElasticAPM::Sinatra.start(
  MyApp,
  service_name: 'SomeOtherName'
)
```

See [Getting started with Rack](/reference/getting-started-rack.md).


## Grape and Rack [_grape_and_rack]

When using Grape and Rack (without Rails), configure when starting the agent:

```ruby
# config.ru or similar
ElasticAPM::Grape.start(
  MyApp,
  service_name: 'SomeOtherName'
)
```

See [Getting started with Rack](/reference/getting-started-rack.md).


## Options [_options]


### `config_file` [config-config-file]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_CONFIG_FILE` | `config_file` | `config/elastic_apm.yml` |

The path to the configuration YAML-file. Elastic APM will load config options from this if the file exists. The file will be evaluated as ERB, so you can include `ENV` variables like in your `database.yml`, eg:

```ruby
secret_token: <%= ENV['VERY_SECRET_TOKEN'] %>
```


### `server_url` [config-server-url]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_SERVER_URL` | `server_url` | `'http://localhost:8200'` |

The URL for your APM Server. The URL must be fully qualified, including protocol (`http` or `https`) and port.


### `secret_token` [config-secret-token]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_SECRET_TOKEN` | `secret_token` | `nil` | A random string |

This string is used to ensure that only your agents can send data to your APM server. Both the agents and the APM server have to be configured with the same secret token. Here’s an example that generates a secure secret token:

```bash
ruby -r securerandom -e 'print SecureRandom.uuid'
```

::::{warning}
Secret tokens only provide any real security if your APM server uses TLS.
::::



### `api_key` [config-api-key]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_API_KEY` | `api_key` | `nil` | A base64-encoded string |

This base64-encoded string is used to ensure that only your agents can send data to your APM server. The API key must be created using the [APM server command-line tool](docs-content://solutions/observability/apps/api-keys.md).

::::{warning}
API keys only provide any real security if your APM server uses TLS.
::::



### `api_buffer_size` [config-api-buffer-size]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_API_BUFFER_SIZE` | `api_buffer_size` | `256` |

The maximum amount of objects kept in queue before sending to APM Server.

If you hit the limit, consider increasing the agent’s [worker pool size](#config-pool-size). If you don’t, the agent may have trouble connecting to APM Server. The [logs](#config-log-path) should tell you what went wrong.


### `api_request_size` [config-api-request-size]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_API_REQUEST_SIZE` | `api_request_size` | `"750kb"` |

The maximum amount of bytes sent over one request to APM Server. The agent will open a new request when this limit is reached.

This must be provided in **[size format](#config-format-size)**.


### `api_request_time` [config-api-request-time]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_API_REQUEST_TIME` | `api_request_time` | `"10s"` |

The maximum duration of a single streaming request to APM Server before opening a new one.

The APM Server has its own limit of 30 seconds before it will close requests. This must be provided in **[duration format](#config-format-duration)**.


### `breakdown-metrics` [config-breakdown-metrics]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_BREAKDOWN_METRICS` | `breakdown_metrics` | `true` |

Enable or disable the tracking and collection of breakdown metrics. Setting this to `False` disables the tracking of breakdown metrics, which can reduce the overhead of the agent.

::::{note}
This feature requires APM Server and Kibana >= 7.3.
::::



### `capture_body` [config-capture-body]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

|     |     |     |     |
| --- | --- | --- | --- |
| Environment | `Config` key | Default | Example |
| `ELASTIC_APM_CAPTURE_BODY` | `capture_body` | `"off"` | `"all"` |

The Ruby agent can optionally capture the request body (e.g. `POST` variables or JSON data) for transactions that are HTTP requests.

Possible values: `"errors"`, `"transactions"`, `"all"`, `"off"`.

If the request has a body and this setting is disabled, the body will be shown as `[SKIPPED]`.

::::{warning}
Request bodies often contain sensitive values like passwords and credit card numbers. We try to strip sensitive looking data from form bodies but don’t touch text bodies like JSON. If your service handles data like this, we advise to only enable this feature with care.
::::



### `capture_headers` [config-capture-headers]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_CAPTURE_HEADERS` | `capture_headers` | `true` |

This indicates whether or not to attach the request headers to transactions and errors.


### `capture_elasticsearch_queries` [config-capture-elasticsearch-queries]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_CAPTURE_ELASTICSEARCH_QUERIES` | `capture_elasticsearch_queries` | `false` |

This indicates whether or not to capture the body from requests in Elasticsearch.


### `capture_env` [config-capture-env]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_CAPTURE_ENV` | `capture_env` | `true` |

This indicates whether or not to attach `ENV` from Rack to transactions and errors.


### `central_config` [config-central-config]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_CENTRAL_CONFIG` | `central_config` | `true` |

This enables [APM Agent Configuration via Kibana](docs-content://solutions/observability/apps/apm-agent-central-configuration.md). If set to `true`, the client will poll the APM Server regularly for new agent configuration.

Usually APM Server determines how often to poll, but if not, set the default interval is 5 minutes.

::::{note}
This feature requires APM Server v7.3 or later. See [APM Agent central configuration](docs-content://solutions/observability/apps/apm-agent-central-configuration.md) for more information.
::::



### `cloud_provider` [config-cloud-provider]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_CLOUD_PROVIDER` | `cloud_provider` | `"auto"` |

Specify the cloud provider for metadata collection. This defaults to `"auto"`, which means the agent uses trial and error to collect metadata from all supported cloud providers.

Valid options are `"auto"`, `"aws"`, `"gcp"`, `"azure"`, and `"none"`. If set to `"none"`, no cloud metadata will be collected. If set to any of `"aws"`, `"gcp"`, or `"azure"`, attempts to collect metadata will only be performed from the chosen provider.


### `disable_metrics` [config-disable_metrics]

|     |     |     |     |
| --- | --- | --- | --- |
| Environment | `Config` key | Default | Example |
| `ELASTIC_APM_DISABLE_METRICS` | `disable_metrics` | [] | `"*.cpu.*,system.memory.total"` |

A comma-separated list of dotted metrics names that should not be sent to the APM Server. You can use `*` to match multiple metrics. Matching is not case sensitive.


### `disable_send` [config-disable-send]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_DISABLE_SEND` | `disable_send` | `false` |

This disables sending payloads to APM Server.


### `disable_start_message` [config-disable-start-message]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_DISABLE_START_MESSAGE` | `disable_start_message` | `false` |

This disables the agents startup message announcing itself.


### `disable_instrumentations` [config-disabled-instrumentations]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_DISABLE_INSTRUMENTATIONS` | `disable_instrumentations` | `['json']` |

Elastic APM automatically instruments select third-party libraries. Use this option to disable any of these.

Get an array of enabled instrumentations with `ElasticAPM.agent.config.enabled_instrumentations`.


### `enabled` [config-enabled]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_ENABLED` | `enabled` | `true` |

Indicates whether or not to start the agent. If `enabled` is `false`, `ElasticAPM.start` will do nothing and all calls to the root API will return `nil`.


### `environment` [config-environment]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_ENVIRONMENT` | `environment` | From `ENV` | `"production"` |

The name of the environment this service is deployed in, e.g. "production" or "staging".

Environments allow you to easily filter data on a global level in the APM app. Be consistent when naming environments across agents. See [environment selector](docs-content://solutions/observability/apps/filter-application-data.md#apm-filter-your-data-service-environment-filter) in the APM app for more information.

Defaults to `ENV['RAILS_ENV'] || ENV['RACK_ENV']`.

::::{note}
This feature is fully supported in the APM app in Kibana versions >= 7.2. You must use the query bar to filter for a specific environment in versions prior to 7.2.
::::



### `filter_exception_types` [config-filter-exception-types]

|     |     |     |     |
| --- | --- | --- | --- |
| Environment | `Config` key | Default | Example |
| N/A | `filter_exception_types` | `[]` | `[MyApp::Errors::IgnoredError]` |

Use this to filter error tracking for specific error constants.


### `framework_name` [config-framework-name]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_FRAMEWORK_NAME` | `framework_name` | Depending on framework |

The name of the used framework. For Rails or Sinatra, this defaults to `Ruby on Rails` and `Sinatra` respectively, otherwise defaults to `nil`.


### `framework_version` [config-framework-version]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_FRAMEWORK_VERSION` | `framework_version` | Depending on framework |

The version number of the used framework. For Ruby on Rails and Sinatra, this defaults to the used version of the framework, otherwise, the default is `nil`.


### `global_labels` [config-global-labels]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_GLOBAL_LABELS` | `global_labels` | `nil` | `dept=engineering,rack=number8` |

Labels added to all events, with the format key=value[,key=value[,…​]].

::::{note}
This option requires APM Server 7.2 or greater, and will have no effect when using older server versions.
::::



### `hostname` [config-hostname]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_HOSTNAME` | `hostname` | `hostname` | `app-server01.example.com` |

The host name to use when sending error and transaction data to the APM server.


### `ignore_url_patterns` [config-custom-ignore-url-patterns]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_IGNORE_URL_PATTERNS` | `ignore_url_patterns` | `[]` | `['^/ping', %r{^/admin}]` |

Use this option to ignore certain URL patterns such as healthchecks or admin sections.

*Ignoring* in this context means *don’t wrap in a [Transaction](/reference/api-reference.md#api-transaction)*. Errors will still be reported.

Use a comma separated string when setting this option via `ENV`. Eg. `ELASTIC_APM_IGNORE_URL_PATTERNS="a,b" # => [/a/, /b/]`


### `instrument` [config-instrument]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_INSTRUMENT` | `instrument` | `true` | `0` |

Use this option to ignore certain URL patterns such as healthchecks or admin sections.


### `instrumented_rake_tasks` [config-instrumented-rake-tasks]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_INSTRUMENTED_RAKE_TASKS` | `instrumented_rake_tasks` | `[]` | `['my_task']` |

Elastic APM can instrument your Rake tasks. This is an opt-in field, as they are used are for a multitude of things.


### `log_ecs_reformatting` [config-log-ecs-formatting]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_LOG_ECS_REFORMATTING` | `log_ecs_reformatting` | `off` |

This is an experimental option that configures the agent to use the logger from the `ecs-logging` gem. The two valid options are `off` and `override`.

Setting this option to `override` will set the agent logger to a `EcsLogging::Logger` instance and all logged output will be in ECS-compatible json.

The `ecs-logging` gem must be installed before the agent is started. If `log_ecs_reformatting` is set to `override`, the agent will attempt to require the gem and if it cannot be loaded, it will fall back to using the standard Ruby `::Logger` and log the load error.

Note that if you’re using Rails, the agent will ignore this option and use the Rails logger. If you want to use a `EcsLogging::Logger` when using Rails, set the agent’s logger config option explicitly to a `EcsLogging::Logger` instance.


### `log_level` [config-log-level]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_LOG_LEVEL` | `log_level` | `Logger::INFO # => 1` |

By default Elastic APM logs to `stdout` or uses `Rails.log` when used with Rails.


### `log_path` [config-log-path]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_LOG_PATH` | `log_path` | `nil` | `log/elastic_apm.log` |

A path to a log file.

By default Elastic APM logs to `stdout` or uses `Rails.log` when used with Rails.

If `log_path` is specified, this will override `Rails.log` to point to that path instead.

This should support both absolute and relative paths. Please be sure the directory exists.


### `logger` [config-logger]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| N/A | `logger` | Depends | `Logger.new('path/to_file.log')` |

By default Elastic APM logs to `stdout` or uses `Rails.log` when used with Rails.

Use this to provide another logger. This is expected to have the same API as Ruby’s built-in `Logger`.


### `metrics_interval` [config-metrics-interval]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_METRICS_INTERVAL` | `metrics_interval` | `'30s'` |

Specify the interval for reporting metrics to APM Server. The interval should be in seconds, or include a time suffix.

To disable metrics reporting, set the interval to `0`.


### `pool_size` [config-pool-size]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_POOL_SIZE` | `pool_size` | `1` | `2` |

Elastic APM uses a thread pool to send its data to APM Server.

This makes sure the agent doesn’t block the main thread any more than necessary.

If you have high load and get warnings about the buffer being full, increasing the worker pool size might help.


### `proxy_address` [config-proxy-address]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_PROXY_ADDRESS` | `proxy_address` | `nil` | `"example.com"` |

An address to use as a proxy for the HTTP client.

Options available are:

* `proxy_address`
* `proxy_headers`
* `proxy_password`
* `proxy_port`
* `proxy_username`

There are also `ENV` version of these following the same pattern of putting `ELASTIC_APM_` in front.

See [Http.rb’s docs](https://github.com/httprb/http/wiki/Proxy-Support).


### `recording` [config-recording]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_RECORDING` | `recording` | `true` |

Enable or disable the recording of events. If set to `false`, then the agent does not create or send any events to the Elastic APM server, and instrumentation overhead is minimized. The agent continues to poll the server for configuration changes when this option is false.


### `sanitize_field_names` [config-sanitize-field-names]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_SANITIZE_FIELD_NAMES` | `sanitize_field_names` | `"password,passwd,pwd,secret,*key,*token*,*session*,*credit*,*card*,*auth*,set-cookie"` | `Auth*tion,abc*,*xyz` |

Sometimes it is necessary to sanitize the data sent to Elastic APM to remove sensitive values.

Configure a list of wildcard patterns of field names which should be sanitized. These apply to HTTP headers and bodies, if they’re being captured.

Supports the wildcard `*`, which matches zero or more characters. Examples: `/foo/*/bar/*/baz*`, `*foo*`. Matching is case insensitive.


### `service_name` [config-service-name]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_SERVICE_NAME` | `service_name` | App’s name | `MyApp` |

The name of your service. This is used to group the errors and transactions of your service and is the primary filter in the Elastic APM user interface.

If you’re using Ruby on Rails this will default to your app’s name. If you’re using Sinatra it will default to the name of your app’s class.

::::{note}
The service name must conform to this regular expression: `^[a-zA-Z0-9 _-]+$`. In other words, it must only contain characters from the ASCII alphabet, numbers, dashes, underscores, and spaces.
::::



### `service_node_name` [config-service-node-name]

```
[options="header"]
```
|     |     |     |     |
| --- | --- | --- | --- |
| Environment | `Config` key | Default | Example |
| `ELASTIC_APM_SERVICE_NODE_NAME` | `service_node_name` | `nil` | `"my-app-1"` |

The name of the given service node. This is optional, and if omitted, the APM Server will fall back on `system.container.id` if available, and `host.name` if necessary.

This option allows you to set the node name manually to ensure it’s unique and meaningful.


### `service_version` [config-service-version]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_SERVICE_VERSION` | `service_version` | `git` sha | A string indicating the version of the deployed service |

The deployed version of your service. This defaults to `git rev-parse --verify HEAD`.


### `source_lines_error_app_frames` [config-source-lines-error-app-frames]


### `source_lines_error_library_frames` [config-source-lines-error-library-frames]


### `source_lines_span_app_frames` [config-source-lines-span-app-frames]


### `source_lines_span_library_frames` [config-source-lines-span-library-frames]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_SOURCE_LINES_ERROR_APP_FRAMES` | `source_lines_error_app_frames` | `5` |
| `ELASTIC_APM_SOURCE_LINES_ERROR_LIBRARY_FRAMES` | `source_lines_error_library_frames` | `5` |
| `ELASTIC_APM_SOURCE_LINES_SPAN_APP_FRAMES` | `source_lines_span_app_frames` | `0` |
| `ELASTIC_APM_SOURCE_LINES_SPAN_LIBRARY_FRAMES` | `source_lines_span_library_frames` | `0` |

By default, the APM agent collects source code snippets for errors. Use the above settings to modify how many lines of source code are collected.

We differ between errors and spans, as well as library frames and app frames.

::::{warning}
Especially for spans, collecting source code can have a large impact on storage use in your Elasticsearch cluster.
::::



### `span_frames_min_duration` [config-span-frames-min-duration-ms]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_SPAN_FRAMES_MIN_DURATION` | `span_frames_min_duration` | `"5ms"` |

Use this to disable stack trace frame collection for spans with a duration shorter than or equal to the given amount of milleseconds.

The default is `"5ms"`.

Set it to `-1` to collect stack traces for all spans. Set it to `0` to disable stack trace collection for all spans.

It has to be provided in **[duration format](#config-format-duration)**.


### `server_ca_cert_file` [config-ssl-ca-cert]

| Environment | `Config` key | Default | Example |
| --- | --- | --- | --- |
| `ELASTIC_APM_SERVER_CA_CERT_FILE` | `server_ca_cert_file` | `nil` | `'/path/to/ca.pem'` |

The path to a custom CA certificate for connecting to APM Server.


### `stack_trace_limit` [config-stack-trace-limit]

| Environment | `Config` key | Default |
| --- | --- | --- |
| `ELASTIC_APM_STACK_TRACE_LIMIT` | `stack_trace_limit` | `999999` |

The maximum number of stack trace lines per span/error.


### `transaction_max_spans` [config-transaction-max-spans]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_TRANSACTION_MAX_SPANS` | `transaction_max_spans` | `500` |

Limits the amount of spans that are recorded per transaction. This is helpful in cases where a transaction creates a very high amount of spans (e.g. thousands of SQL queries). Setting an upper limit will prevent overloading the agent and the APM server with too much work for such edge cases.


### `transaction_sample_rate` [config-transaction-sample-rate]

[![dynamic config](../images/dynamic-config.svg "") ](#dynamic-configuration)

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_TRANSACTION_SAMPLE_RATE` | `transaction_sample_rate` | `1.0` |

By default, the agent will sample every transaction (e.g. request to your service). To reduce overhead and storage requirements, you can set the sample rate to a value between `0.0` and `1.0`. We still record overall time and the result for unsampled transactions, but no context information, tags, or spans. The sample rate will be rounded to 4 digits of precision.


### `verify_server_cert` [config-verify-server-cert]

|     |     |     |
| --- | --- | --- |
| Environment | `Config` key | Default |
| `ELASTIC_APM_VERIFY_SERVER_CERT` | `verify_server_cert` | `true` |

By default, the agent verifies the SSL certificate if you use an HTTPS connection to the APM server. Verification can be disabled by changing this setting to `false`.


## Configuration formats [config-formats]

Some options require a unit, either duration or size. These need to be provided in a specific format.


### Duration format [config-format-duration]

The *duration* format is used for options like timeouts. The unit is provided as suffix directly after the number, without any separation by whitespace.

**Example**: `"5ms"`

**Supported units**

* `ms` (milliseconds)
* `s` (seconds)
* `m` (minutes)


### Size format [config-format-size]

The *size* format is used for options like maximum buffer sizes. The unit is provided as suffix directly after the number, without any separation by whitespace.

**Example**: `10kb`

**Supported units**:

* `b` (bytes)
* `kb` (kilobytes)
* `mb` (megabytes)
* `gb` (gigabytes)

::::{note}
We use the power-of-two sizing convention, e.g. `1 kilobyte == 1024 bytes`.
::::



## Special configuration [special-configuration]

Elastic APM patches `Kernel#require` to auto-detect and instrument supported third-party libraries. It does so with the utmost care but in rare cases, it can conflict with some libraries.

To get around this patch, set the environment variable `ELASTIC_APM_SKIP_REQUIRE_PATCH` to `"1"`.

The agent might need some additional tweaking to make sure the third-party libraries are picked up and instrumented. Make sure you require the agent *after* you require your other dependencies.

