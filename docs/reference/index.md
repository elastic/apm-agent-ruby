---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/introduction.html
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/index.html
---

# APM Ruby agent [introduction]

The Elastic APM Ruby Agent sends performance metrics and error logs to the APM Server. It has built-in support for [Ruby on Rails](/reference/getting-started-rails.md) and other [Rack-compatible](/reference/getting-started-rack.md) applications. It also offers an API which allows you to instrument any application.


## How does the Agent work? [how-it-works]

The agent auto-instruments [supported technologies](/reference/supported-technologies.md) and records interesting events, like HTTP requests and database queries. To do this, it uses relevant public APIs when they are provided by the libraries. Otherwise, it carefully wraps the necessary internal methods. This means that for the supported technologies, there are no code changes required.

The Agent automatically keeps track of queries to your data stores to measure their duration and metadata (like the DB statement), as well as HTTP related information (like the URL, parameters, and headers).

These events, called Transactions and Spans, are sent to the APM Server. The APM Server converts them to a format suitable for Elasticsearch, and sends them to an Elasticsearch cluster. You can then use the APM app in Kibana to gain insight into latency issues and error culprits within your application.


## Additional Components [additional-components]

APM Agents work in conjunction with the [APM Server](docs-content://solutions/observability/apps/application-performance-monitoring-apm.md), [Elasticsearch](docs-content://get-started/index.md), and [Kibana](docs-content://get-started/the-stack.md). The [APM Guide](docs-content://solutions/observability/apps/application-performance-monitoring-apm.md) provides details on how these components work together, and provides a matrix outlining [Agent and Server compatibility](docs-content://solutions/observability/apps/apm-agent-compatibility.md).

