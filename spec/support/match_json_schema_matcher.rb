# frozen_string_literal: true

require 'spec_helper'
require 'json-schema'

base = 'https://raw.githubusercontent.com/elastic/apm-server/master/docs/spec'

SCHEMA_URLS = {
  metadatas: base + '/metadata.json',
  transactions: base + '/transactions/transaction.json',
  spans: base + '/spans/span.json',
  errors: base + '/errors/error.json',
  metricset: base + '/metricsets/metricset.json'
}.freeze

RSpec::Matchers.define :match_json_schema do |schema|
  match do |json|
    begin
      WebMock.disable!
      url = SCHEMA_URLS.fetch(schema)
      JSON::Validator.validate!(url, json)
    rescue JSON::ParserError # jruby sometimes weirds out
      puts json.inspect
      raise
    rescue JSON::Schema::ValidationError
      puts json.inspect
      raise
    ensure
      WebMock.enable!
    end
  end
end
