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

require 'spec_helper'

module ElasticAPM
  RSpec.describe TraceContext::Traceparent do
    describe '.new' do
      subject { described_class.new }

      its(:version) { should eq '00' }
      its(:trace_id) { should match(/.{16}/) }
      its(:id) { should match(/.{8}/) }
      its(:parent_id) { should be_nil }
      it { should be_recorded }
    end

    describe '.parse' do
      let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00' }

      subject { described_class.parse header }

      context 'with a common header' do
        it { expect { subject }.to_not raise_error }
        its(:version) { should eq '00' }
        its(:trace_id) { should eq '0af7651916cd43dd8448eb211c80319c' }
        its(:parent_id) { should eq 'b7ad6b7169203331' }
        its(:id) { should_not be_nil }
        its(:id) { should_not eq 'b7ad6b7169203331' }
        its(:flags) { should eq '00000000' }
      end

      context 'with a blank header' do
        let(:header) { '' }
        it do
          expect { subject }
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end

      context 'when recorded' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'
        end
        it { should be_recorded }
      end

      context 'with unknown version' do
        let(:header) do
          '01-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end

      context 'with non-hex trace id' do
        let(:header) do
          '00-Ggf7651916cd43dd8448eb211c80319c-b7ad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end

      context 'with non-hex parent id' do
        let(:header) do
          '00-0af7651916cd43dd8448eb211c80319c-XXad6b7169203331-03'
        end
        it do
          expect { subject }
            .to raise_error(TraceContext::InvalidTraceparentHeader)
        end
      end
    end

    describe '#ensure_parent_id' do
      let(:parent_id) { nil }
      subject(:tc) { described_class.new parent_id: parent_id }

      context 'parent_id set' do
        let(:parent_id) { 'b7ad6b7169203331' }
        it "doesn't change parent_id" do
          expect(tc.ensure_parent_id).to eq parent_id
          expect(tc.parent_id).to eq parent_id
        end
      end

      it 'sets and returns parent_id' do
        pid = tc.ensure_parent_id
        expect(tc.parent_id).to eq pid
      end
    end

    describe '#child' do
      let(:header) { '00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-00' }
      let(:parent) { described_class.parse header }

      subject { parent.child }

      it 'makes a child copy' do
        expect(subject.parent_id).to eq parent.id
        expect(subject.id).not_to eq parent.id
      end
    end

    describe '#to_header' do
      subject do
        described_class.new.tap do |tp|
          tp.trace_id = '1' * 32
          tp.id = '2' * 16
          tp.flags = '00000011'
        end
      end

      its(:to_header) do
        should match('00-11111111111111111111111111111111-2222222222222222-01')
      end
    end

    describe '#flags' do
      context 'with flags as props' do
        subject do
          described_class.new.tap do |tp|
            tp.recorded = true
          end
        end
        its(:flags) { should eq '00000001' }
      end
    end
  end
end
