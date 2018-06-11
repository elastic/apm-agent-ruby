# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Added an option to disable metrics collection ([#145](https://github.com/elastic/apm-agent-ruby/pulls/145))
- Filters can cancel the entire payload by returning `nil` ([#148](https://github.com/elastic/apm-agent-ruby/pulls/148))
- Added `ENV` version of the logging options ([#146](https://github.com/elastic/apm-agent-ruby/pull/146))

### Fixed

- Remove newline on `hostname`

## 0.7.4 - 2018-06-07

Beginning of this document

### Fixed

- Fix overwriting custom logger with Rails'
