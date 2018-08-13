# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Transaction do
    let(:config) { Config.new }
    let(:instrumenter) { Instrumenter.new Agent.new(config) }

    describe '#initialize', :mock_time do
      it 'has no spans, timestamp and start time' do
        transaction = Transaction.new instrumenter

        expect(transaction.spans.length).to be 0
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

    describe '#release', :mock_time do
      it 'sets clients current transaction to nil' do
        transaction = Transaction.new instrumenter, 'Test'
        transaction.release

        expect(instrumenter.current_transaction).to be_nil
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

    describe '#submit', :mock_time do
      it 'ends transaction and submits it to the agent' do
        allow(instrumenter).to receive(:current_transaction=)
        allow(instrumenter).to receive(:submit_transaction)

        transaction = Transaction.new instrumenter, 'Test'

        travel 100
        transaction.submit 200

        expect(transaction.result).to be 200
        expect(transaction).to be_done
        expect(instrumenter).to have_received(:current_transaction=)
        expect(instrumenter)
          .to have_received(:submit_transaction)
          .with transaction
      end
    end

    describe '#span', :mock_time do
      let(:transaction) { Transaction.new instrumenter, 'Test' }
      subject do
        transaction

        travel 100

        span = transaction.span 'test' do |t|
          travel 100
          t
        end

        transaction.done

        span
      end

      it { should be_done }
      it { should_not be_running }

      it 'gets an id' do
        expect(subject.id).to be 0
      end

      it 'sets start time' do
        expect(subject.relative_start).to eq 100_000
      end

      it 'knows its parent spans' do
        expect(subject.parent).to be_nil
      end

      it 'adds span to spans' do
        expect(transaction.spans).to eq [subject]
      end
    end

    context 'when not sampled' do
      it "doesn't collect spans, context" do
        transaction =
          Transaction.new(instrumenter, 'Test', sampled: false) do |t|
            t.span 'Things' do
              'ok'
            end

            t.span 'Other things' do
              'also ok'
            end

            t
          end

        expect(transaction).to_not be_sampled
        expect(transaction.spans).to be_empty
      end
    end

    context 'when reaching max span cound' do
      let(:config) { Config.new(transaction_max_spans: 2) }

      it 'stops recording spans and bumps dropped count instead' do
        transaction =
          Transaction.new instrumenter, 'T with too many spans' do |t|
            t.span 'Thing 1'
            t.span 'Thing 2'
            t.span 'Thing 3'
            t
          end

        expect(transaction.spans.length).to be 2
        expect(transaction.dropped_spans).to be 1
      end
    end
  end
end
