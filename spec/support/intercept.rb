# Licensed to Elasticsearch B.V. under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Elasticsearch B.V. licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# frozen_string_literal: true

RSpec.configure do |config|
  class Intercept
    def initialize
      @transactions = []
      @spans = []
      @errors = []
      @metricsets = []

      @span_types = JSON.parse(File.read('./spec/fixtures/span_types.json'))
    end

    attr_reader :transactions, :spans, :errors, :metricsets

    def submit(obj)
      case obj
      when ElasticAPM::Transaction
        transactions << obj
      when ElasticAPM::Span
        validate_span!(obj)
        spans << obj
      when ElasticAPM::Error
        errors << obj
      when ElasticAPM::Metricset
        metricsets << obj
      end

      true
    end

    def start; end

    def stop; end

    def validate_span!(span)
      begin
        type = @span_types.fetch(span.type)
      rescue KeyError
        raise "Unknown span.type `#{span.type}'\nPossible types: #{@span_types.keys.join(', ')}"
      end

      if !type['optional_subtype'] && !span.subtype
        raise "span.subtype missing when required,\nPossible subtypes: #{subtypes}"
      end

      return unless (subtypes = type['subtypes'])

      subtypes.fetch(span.subtype)
    rescue KeyError
      raise "Unknown span.subtype `#{span.type}'\nPossible subtypes: #{subtypes}"
    end
  end

  module Methods
    def intercept!
      return if @intercepted

      @intercepted = Intercept.new

      allow(ElasticAPM::Transport::Base).to receive(:new) do |*_args|
        @intercepted
      end
    end
  end

  config.include Methods

  config.before :each, intercept: true do
    intercept!
  end

  config.after :each, intercept: true do
    @intercepted = nil
  end
end
