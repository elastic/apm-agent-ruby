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

require 'elastic_apm/normalizers'
require 'elastic_apm/normalizers/rails'

module ElasticAPM
  module Normalizers
    RSpec.describe ActionView do
      let(:normalizers) do
        config = Config.new.tap do |c|
          c.__view_paths = ['/var/www/app/views']
        end
        Normalizers.build(config)
      end

      shared_examples_for :action_view_normalizer do |key|
        describe '#normalize' do
          it 'normalizes an unknown template' do
            result = subject.normalize(nil, key, {})
            type = described_class.const_get(:TYPE)
            subtype = described_class.const_get(:SUBTYPE)
            expected = ['Unknown template', type, subtype, action, nil]

            expect(result).to eq expected
          end

          it 'returns a local template' do
            path = 'somewhere/local.html.erb'
            result, * = subject.normalize(nil, key, identifier: path)
            expect(result).to eq 'somewhere/local.html.erb'
          end

          it 'looks up a template in config.view_paths' do
            path = '/var/www/app/views/users/index.html.erb'
            result, * = subject.normalize(nil, key, identifier: path)
            expect(result).to eq 'users/index.html.erb'
          end

          it 'truncates gem path' do
            path = Gem.path[0] + '/some/template.html.erb'
            result, * = subject.normalize(nil, key, identifier: path)
            expect(result).to eq '$GEM_PATH/some/template.html.erb'
          end

          it 'returns absolute if not found in known dirs' do
            path = '/somewhere/else.html.erb'
            expect(subject.normalize(nil, key, identifier: path)[0])
              .to eq 'Absolute path'
          end
        end
      end

      describe ActionView::RenderTemplateNormalizer do
        let(:action) { nil }
        subject { normalizers.for('render_template.action_view') }
        it { expect(subject).to be_a ActionView::RenderTemplateNormalizer }
        it_should_behave_like :action_view_normalizer
      end

      describe ActionView::RenderPartialNormalizer do
        let(:action) { 'partial' }
        subject { normalizers.for('render_partial.action_view') }
        it { expect(subject).to be_a ActionView::RenderPartialNormalizer }
        it_should_behave_like :action_view_normalizer
      end

      describe ActionView::RenderCollectionNormalizer do
        let(:action) { 'collection' }
        subject { normalizers.for('render_collection.action_view') }
        it { expect(subject).to be_a ActionView::RenderCollectionNormalizer }
        it_should_behave_like :action_view_normalizer
      end
    end
  end
end
