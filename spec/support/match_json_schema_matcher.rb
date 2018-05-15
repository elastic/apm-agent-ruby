# frozen_string_literal: true

require 'spec_helper'

SCHEMA_URLS = {
  transactions: 'https://github.com/elastic/apm-server/raw/master/docs/spec/transactions/payload.json',
  errors: 'https://github.com/elastic/apm-server/raw/master/docs/spec/errors/payload.json'
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
