# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## 1.0.0.beta2 (2018-06-21)

### Added

- Added config.disable_send ([#156](https://github.com/elastic/apm-agent-ruby/pulls/156))

### Fixed

- Fixed some Elasticsearch spans not validating JSON Schema ([#157](https://github.com/elastic/apm-agent-ruby/pulls/157))

## 1.0.0.beta1 (2018-06-14)

## 0.8.0 (2018-06-13)

### Added

- Added an option to disable metrics collection ([#145](https://github.com/elastic/apm-agent-ruby/pulls/145))
- Filters can cancel the entire payload by returning `nil` ([#148](https://github.com/elastic/apm-agent-ruby/pulls/148))
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
