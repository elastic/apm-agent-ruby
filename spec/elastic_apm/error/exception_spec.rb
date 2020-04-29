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

module ElasticAPM
  RSpec.describe Error::Exception do
    describe '#initialize' do
      it 'takes an exception and optional attributes' do
        exc = Error::Exception.from_exception(
          ZeroDivisionError.new, message: 'Things'
        )
        expect(exc.message).to eq 'Things'
        expect(exc.type).to eq 'ZeroDivisionError'
      end

      context 'with an exception chain' do
        it 'chains the causes' do
          exc = Error::Exception.from_exception actual_chained_exception,
            message: 'Things'
          expect(exc.message).to eq 'Things'
          expect(exc.type).to eq 'ExceptionHelpers::One'

          cause1 = exc.cause
          expect(cause1).to be_a Error::Exception
          expect(cause1.message).to eq 'ExceptionHelpers::Two'
          expect(cause1.type).to eq 'ExceptionHelpers::Two'

          cause2 = cause1.cause
          expect(cause2).to be_a Error::Exception
          expect(cause2.message).to eq 'ExceptionHelpers::Three'
          expect(cause2.type).to eq 'ExceptionHelpers::Three'
        end
      end
    end
  end
end
