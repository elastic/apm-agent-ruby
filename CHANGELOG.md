# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

### Deprecated

- `ElasticAPM.build_context` now takes two keyword arguments instead of a single, normal argument. [Docs](https://www.elastic.co/guide/en/apm/agent/ruby/2.x/api.html#api-agent-build-context).
- The option `capture_body` has a string value instead of boolean. [Docs](https://www.elastic.co/guide/en/apm/agent/ruby/2.x/configuration.html#config-capture-body).

Both APIs are backwards compatible with fallbacks and deprecation warnings, scheduled for removal in next major release.

### Added 

- Configuration options to use an HTTP proxy ([#352](https://github.com/elastic/apm-agent-ruby/pull/352))

### Changed

- Errors get their own contexts, perhaps leading to slightly different (but more correct) results. ([#335](https://github.com/elastic/apm-agent-ruby/pull/335))
- The agent no longer starts automatically inside Rails' console ([#343](https://github.com/elastic/apm-agent-ruby/pull/343))

### Fixed

- Fixed reading available memory on older Linux kernels ([#351](https://github.com/elastic/apm-agent-ruby/pull/351))
- Don't apply filters to original response headers ([#354](https://github.com/elastic/apm-agent-ruby/pull/354))

## 2.5.0 (2019-03-01)

### Added

- Added the option `active` that will prevent the agent from starting if set to `false` ([#338](https://github.com/elastic/apm-agent-ruby/pull/338))

### Fixed

- Fix error with `capture_body` and nested request bodies ([#339](https://github.com/elastic/apm-agent-ruby/pull/339))

## 2.4.0 (2019-02-27)

### Added

- Added option to specify a custom server CA certificate ([#315](https://github.com/elastic/apm-agent-ruby/pull/315))

### Changed

- **NB:** Default value of option `capture_body` flipped to `false` to align with other agents. Set `capture_body: true` in your configuration to get them back. ([#324](https://github.com/elastic/apm-agent-ruby/pull/324))

### Fixed

- Reading CPU stats from `/proc/stat` on RHEL ([#312](https://github.com/elastic/apm-agent-ruby/pull/312))
- Change TraceContext to differentiate between `id` and `parent_id` ([#326](https://github.com/elastic/apm-agent-ruby/pull/326))
- `capture_body` will now force encode text bodies to utf-8 when possible ([#332](https://github.com/elastic/apm-agent-ruby/pull/332))

## 2.3.1 (2019-01-31)

### Added

- Read container info from Docker or Kupernetes ([#303](https://github.com/elastic/apm-agent-ruby/pull/303))

### Fixed

- Fix logging exceptions when booting via Railtie ([#306](https://github.com/elastic/apm-agent-ruby/pull/306))

## 2.3.0 (2019-01-29)

### Added

- Support for Metrics ([#276](https://github.com/elastic/apm-agent-ruby/pull/276))

## 2.2.0 (2019-01-22)

### Added

- Support for [OpenTracing](https://opentracing.io) ([#273](https://github.com/elastic/apm-agent-ruby/pull/273))
- Add capture_* options ([#279](https://github.com/elastic/apm-agent-ruby/pull/279))
- Evaluate the config file as ERB ([#288](https://github.com/elastic/apm-agent-ruby/pull/288))

### Changed

- Rename `Traceparent` object to `TraceContext` ([#271](https://github.com/elastic/apm-agent-ruby/pull/271))

### Fixed

- An issue where Spans would not get Stacktraces attached ([#282](https://github.com/elastic/apm-agent-ruby/pull/282))
- Skip `caller` unless needed ([#287](https://github.com/elastic/apm-agent-ruby/pull/283))

## 2.1.2 (2018-12-07)

### Fixed

- Fix truncation of `transaction.request.url` values ([#267](https://github.com/elastic/apm-agent-ruby/pull/267))
- Fix Faraday calls with `url_prefix` ([#263](https://github.com/elastic/apm-agent-ruby/pull/263))
- Force `span.context.http.status_code` to be an integer

## 2.1.1 (2018-12-04)

### Fixed

- Set traceparent span.id to transaction id when span is missing ([#261](https://github.com/elastic/apm-agent-ruby/pull/261))

## 2.1.0 (2018-12-04)

### Added

- Support for Faraday ([#249](https://github.com/elastic/apm-agent-ruby/pull/249))

### Fixed

- Truncate keyword fields to 1024 chars ([#240](https://github.com/elastic/apm-agent-ruby/pull/240))
- Lazy boot worker threads on first event. Fixes apps using Puma's `preload_app!` ([#239](https://github.com/elastic/apm-agent-ruby/pull/239))
- Fix missing `disable_send` implementation ([#257](https://github.com/elastic/apm-agent-ruby/pull/257))
- Add warnings for invalid config options ([#254](https://github.com/elastic/apm-agent-ruby/pull/254))

## 2.0.1 (2018-11-15)

### Fixed

- Stop sending `span.start` ([#234](https://github.com/elastic/apm-agent-ruby/pull/234))

## 2.0.0 (2018-11-14)

Version adds support for APM Server 6.5 and needs at least that.

### Added

- Support for APM Server 6.5 (Intake v2)
- Support for Distributed Tracing (beta)
- Support for RUM Agent correlation (Distributed Tracing)
- Support for [HTTP.rb](https://github.com/httprb/http) (Instrumentation + Distributed Tracing)

### Changed

- Custom instrumentation APIs ([#209](https://github.com/elastic/apm-agent-ruby/pull/209))
- Tag keys will convert disallowed chars to `_`
- Default log level changed to `info`
- Laxed version requirement of concurrent-ruby
- Change `log_level` to only concern agent log

### Deprecated

#### APIs:

- `ElasticAPM.transaction`
- `ElasticAPM.span`

#### Options:

- `compression_level`
- `compression_minimum_size`
- `debug_http`
- `debug_transactions`
- `flush_interval`
- `http_open_timeout`
- `http_read_timeout`
- `enabled_environments`
- `disable_environment_warning`

Some options that used to take a certain unit for granted now expects explicit units – but will fall back to old default.

### Removed

- Support for APM Server versions prior to 6.5.
- Support for Ruby 2.2 (eol)

## 1.1.0 (2018-09-07)

### Added

- Rake task instrumentation ([#192](https://github.com/elastic/apm-agent-ruby/pull/192))
- `default_tags` option ([#183](https://github.com/elastic/apm-agent-ruby/pull/183))

### Fixed

- Fallback from missing JRUBY_VERSION ([#180](https://github.com/elastic/apm-agent-ruby/pull/180))

## 1.0.2 (2018-09-07)

Should've been a minor release -- see 1.1.0

## 1.0.1 (2018-07-30)

### Fixed

- Fixed internal LRU cache to be threadsafe ([#178](https://github.com/elastic/apm-agent-ruby/pull/178))

## 1.0.0 (2018-06-29)

### Added

- Added config.disable_send ([#156](https://github.com/elastic/apm-agent-ruby/pull/156))

### Changed

- Set the default `span_frame_min_duration` to 5ms

### Fixed

- Fixed some Elasticsearch spans not validating JSON Schema ([#157](https://github.com/elastic/apm-agent-ruby/pull/157))

## 0.8.0 (2018-06-13)

### Added

- Added an option to disable metrics collection ([#145](https://github.com/elastic/apm-agent-ruby/pull/145))
- Filters can cancel the entire payload by returning `nil` ([#148](https://github.com/elastic/apm-agent-ruby/pull/148))
- Added `ENV` version of the logging options ([#146](https://github.com/elastic/apm-agent-ruby/pull/146))
- Added `config.ignore_url_patterns` ([#151](https://github.com/elastic/apm-agent-ruby/pull/151))

### Changed

- Use concurrent-ruby's TimerTask instead of `Thread#sleep`. Adds dependency on `concurrent-ruby`. ([#141](https://github.com/elastic/apm-agent-ruby/pull/141))

### Fixed

- Remove newline on `hostname`
- Fixed ActionMailer spans renaming their transaction

## 0.7.4 - 2018-06-07

Beginning of this document

### Fixed

- Fix overwriting custom logger with Rails'
