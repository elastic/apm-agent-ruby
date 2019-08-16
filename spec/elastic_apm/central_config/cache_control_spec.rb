# frozen_string_literal: true

module ElasticAPM
  RSpec.describe CentralConfig::CacheControl do
    let(:header) { nil }
    subject { described_class.new(header) }

    context 'with max-age' do
      let(:header) { 'max-age=300' }
      its(:max_age) { should be 300 }
      its(:must_revalidate) { should be nil }
    end

    context 'with must-revalidate' do
      let(:header) { 'must-revalidate' }
      its(:max_age) { should be nil }
      its(:must_revalidate) { should be true }
    end

    context 'with multiple values' do
      let(:header) { 'must-revalidate, public, max-age=300' }
      its(:max_age) { should be 300 }
      its(:must_revalidate) { should be true }
      its(:public) { should be true }
      its(:private) { should be nil }
    end
  end
end
