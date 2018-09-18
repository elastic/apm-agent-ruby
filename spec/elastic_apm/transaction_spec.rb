# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Transaction do
    let(:config) { Config.new(disable_send: true) }
    let(:instrumenter) { Instrumenter.new Agent.new(config) }

    describe '#initialize', :mock_time do
      it 'has no spans, timestamp and start time' do
        transaction = Transaction.new instrumenter
        expect(transaction.timestamp).to eq 694_224_000_000_000
      end

      it 'has a uuid' do
        expect(Transaction.new(instrumenter).id).to_not be_nil
      end

      it 'has a default type' do
        expect(Transaction.new(instrumenter).type).to_not be_nil
      end

      context 'with default tags' do
        let(:config) { Config.new(default_tags: { test: 'yes it is' }) }

        it 'adds defaults tags' do
          expect(Transaction.new(instrumenter).context.tags)
            .to eq(test: 'yes it is')
        end

        it 'merges with existing context tags' do
          context = Context.new(tags: { test: 'now this', more: 'ok' })

          expect(Transaction.new(instrumenter, context: context).context.tags)
            .to eq(test: 'now this', more: 'ok')
        end
      end
    end

    describe '#done', :mock_time do
      it 'it sets result, durations' do
        transaction = Transaction.new instrumenter, 'Test'

        travel 100
        transaction.done(200)

        expect(transaction.result).to be 200
        expect(transaction.duration).to eq 100_000
      end
    end
  end
end
