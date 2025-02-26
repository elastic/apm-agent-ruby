---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/tuning-and-overhead.html
---

# Performance tuning [tuning-and-overhead]

Using any APM solution comes with trade-offs, and the Elastic APM Ruby Agent is no different. Instrumenting your code, using timers, recording context data, etc., uses resources—for example:

* CPU time
* Memory
* Bandwidth
* Elasticsearch storage

We invest a lot of effort to ensure that the Ruby Agent is suitable for production code and that its overhead remains as low as possible. However, because every application is different, there are some knobs you can turn and tweak to adapt the Agent to your specific needs.


## Transaction sample rate [tuning-sample-rate]

By default, the Agent samples every transaction. The easiest way to reduce both the overhead of the agent and storage requirements, is to tell it to do less, i.e., sample fewer transactions. To do this, set the [`transaction_sample_rate`](/reference/configuration.md#config-transaction-sample-rate) to a value between `0.0` and `1.0`—the percentage of transactions you’d like to randomly sample. The Agent will still record the overall time and result of unsampled transactions, but not context information, tags, or spans.


## Collecting frame context [tuning-frame-context]

The Agent automatically captures several lines of source code around each frame location in the stack trace. This enables the APM app to provide greater insight into exactly where an error or span is occurring in your code. This insight does come at a cost—in terms of performance, stack trace collection is the most expensive thing the Agent does.

There are settings you can modify to control this behavior:

1. Disable stack trace frame collection for short-duration spans by setting [`span_frames_min_duration`](/reference/configuration.md#config-span-frames-min-duration-ms) to `0`.
2. Modify the number of source code lines collected. These settings are divided between app frames, which represent your application code, and library frames, which represent the code of your dependencies. Each of these categories are further split into separate error and span settings.

    * [`source_lines_error_app_frames`](/reference/configuration.md#config-source-lines-error-app-frames)
    * [`source_lines_error_library_frames`](/reference/configuration.md#config-source-lines-error-library-frames)
    * [`source_lines_span_app_frames`](/reference/configuration.md#config-source-lines-span-app-frames)
    * [`source_lines_span_library_frames`](/reference/configuration.md#config-source-lines-span-library-frames)

3. If you’re using the API to create a custom span, you can disable stack trace collection with the [`include_stacktrace` argument](/reference/api-reference.md#api-agent-start_span).

Reading source files inside a running application can cause a lot of disk I/O, and sending up source lines for each frame will have a network and storage cost that is quite high. Turning these limits down will prevent storing excessive amounts of data in Elasticsearch.


## Transaction queue [tuning-queue]

The Agent does not send every transaction as it happens. Instead, to reduce load on the APM Server, the Agent uses a queue. The queue is flushed periodically, or when it reaches a maximum size.

While this reduces the load on the APM Server, holding on to transaction data in a queue uses memory. If you notice a large increase in memory use, try adjusting these settings:

* [`api_request_time`](/reference/configuration.md#config-api-request-time) to reduce the duration of a single streaming request. This setting is helpful if you have a sustained high number of transactions.
* [`api_request_size`](/reference/configuration.md#config-api-request-size) to reduce the maximum size of one request. This setting can help if you experience transaction peaks (a large number in a short period of time).

Keep in mind that reducing the value of either setting will cause the agent to send more HTTP requests to the APM Server, potentially causing a higher load.


## Spans per transaction [tuning-max-spans]

The number of spans per transaction will influence both how much time the agent spends in each transaction collecting contextual data, and how much storage space is needed in Elasticsearch. In our experience, most *usual* transactions should have well below 100 spans. In some cases, however, the number of spans can explode—for example:

* Long-running transactions
* Unoptimized code, e.g., doing hundreds of SQL queries in a loop

To avoid these edge cases which overload both the Agent and the APM Server, the Agent will stop recording spans when a specified limit is reached. This limit is configurable with [`transaction_max_spans`](/reference/configuration.md#config-transaction-max-spans).


## Capturing headers and request body [tuning-body-headers]

You can configure the Agent to capture headers and request bodies with [`capture_headers`](/reference/configuration.md#config-capture-headers) and [`capture_body`](/reference/configuration.md#config-capture-body). By default, headers are captured and request bodies are not.

Depending on the nature of your POST requests, capturing request bodies for transactions may introduce noticeable overhead, as well as increased storage use. In most scenarios, we advise against enabling request body capturing for transactions, and only enabling it if necessary for errors.

Capturing request/response headers has less overhead on the agent than capturing request bodies, but can have an impact on storage use.

