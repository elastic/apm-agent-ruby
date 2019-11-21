# frozen_string_literal: true

module ElasticAPM
  class Config
    RSpec.describe WildcardPatternList::WildcardPattern do
      subject { described_class.new(pattern) }

      [
        ['a*c', 'abc', true],
        ['a*d', 'abcd', true],
        ['a*c', 'abcd', false],
        ['*d', 'abcd', true],
        ['ab*', 'abcd', true],
        ['a.cd', 'abcd', false],
        ['a?cd', 'abcd', false]
      ].each do |(pattern, string, expectation)|
        context pattern do
          let(:pattern) { pattern }

          it "#{expectation ? 'matches' : "doesn't match"} #{string}" do
            expect(subject.match?(string)).to be(expectation)
          end
        end
      end
    end

    RSpec.describe WildcardPatternList do
      let(:patterns) { 'foor.*,*.bar' }

      subject { described_class.new.call patterns }

      it { is_expected.to be_a Array }

      it 'converts to patterns' do
        expect(subject.length).to be 2

        first, last = subject
        expect(first).to be_a WildcardPatternList::WildcardPattern
        expect(last).to be_a WildcardPatternList::WildcardPattern
      end
    end
  end
end
