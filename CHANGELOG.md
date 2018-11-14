# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

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
