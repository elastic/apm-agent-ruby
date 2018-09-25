# frozen_string_literal: true

require 'spec_helper'
require 'json-schema'

SCHEMA_URLS = {
  metadatas: 'https://github.com/elastic/apm-server/raw/v2/docs/spec/metadata.json',
  transactions: 'https://github.com/elastic/apm-server/raw/v2/docs/spec/transactions/v2_transaction.json',
  spans: 'https://github.com/elastic/apm-server/raw/v2/docs/spec/spans/v2_span.json',
  errors: 'https://github.com/elastic/apm-server/raw/v2/docs/spec/errors/v2_error.json'
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
