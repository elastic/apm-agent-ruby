# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased


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
