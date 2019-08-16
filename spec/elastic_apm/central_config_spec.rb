# frozen_string_literal: true

module ElasticAPM
  RSpec.describe CentralConfig do
    let(:config) { Config.new }
    subject { described_class.new(config) }

    describe '#start' do
      it 'polls for config' do
        req_stub = stub_response(transaction_sample_rate: '0.5')
        subject.start
        subject.promise.wait
        expect(req_stub).to have_been_requested
      end

      context 'when disabled' do
        let(:config) { Config.new(central_config: false) }

        it 'does nothing' do
          req_stub = stub_response(transaction_sample_rate: '0.5')
          subject.start
          expect(subject.promise).to be nil
          expect(req_stub).to_not have_been_requested
        end
      end
    end

    describe '#fetch_and_apply_config' do
      it 'queries APM Server and applies config' do
        req_stub = stub_response(transaction_sample_rate: '0.5')
        expect(config.logger).to receive(:info)

        subject.fetch_and_apply_config
        subject.promise.wait

        expect(req_stub).to have_been_requested

        expect(config.transaction_sample_rate).to eq(0.5)
      end

      it 'reverts config if later 404' do
        stub_response(transaction_sample_rate: '0.5')

        subject.fetch_and_apply_config
        subject.promise.wait

        stub_response('Not found', status: 404)

        subject.fetch_and_apply_config
        subject.promise.wait

        expect(config.transaction_sample_rate).to eq(1.0)
      end

      context 'when server responds 200 and cache-control' do
        it 'schedules a new poll' do
          stub_response(
            {},
            headers: { 'Cache-Control': 'must-revalidate, max-age=123' }
          )

          subject.fetch_and_apply_config
          subject.promise.wait

          expect(subject.scheduled_task).to be_pending
          expect(subject.scheduled_task.initial_delay).to eq 123
        end
      end

      context 'when server responds 304' do
        it 'doesn\'t restore config, schedules a new poll' do
          stub_response(
            { transaction_sample_rate: 0.5 },
            headers: { 'Cache-Control': 'must-revalidate, max-age=0.1' }
          )

          subject.fetch_and_apply_config
          subject.promise.wait

          stub_response(
            nil,
            status: 304,
            headers: { 'Cache-Control': 'must-revalidate, max-age=123' }
          )

          subject.fetch_and_apply_config
          subject.promise.wait

          expect(subject.scheduled_task).to be_pending
          expect(subject.scheduled_task.initial_delay).to eq 123
          expect(config.transaction_sample_rate).to eq 0.5
        end
      end

      context 'when server responds 404' do
        it 'schedules a new poll' do
          stub_response('Not found', status: 404)

          subject.fetch_and_apply_config
          subject.promise.wait

          expect(subject.scheduled_task).to be_pending
          expect(subject.scheduled_task.initial_delay).to eq 300
        end
      end
    end

    describe '#fetch_config' do
      context 'when successful' do
        it 'returns response object' do
          stub_response(ok: 1)

          expect(subject.fetch_config).to be_a(HTTP::Response)
        end
      end

      context 'when not found' do
        before do
          stub_response('Not found', status: 404)
        end

        it 'raises an error' do
          expect { subject.fetch_config }
            .to raise_error(CentralConfig::ClientError)
        end

        it 'includes the response' do
          begin
            subject.fetch_config
          rescue CentralConfig::ClientError => e
            expect(e.response).to be_a(HTTP::Response)
          end
        end
      end

      context 'when server error' do
        it 'raises an error' do
          stub_response('Server error', status: 500)

          expect { subject.fetch_config }
            .to raise_error(CentralConfig::ServerError)
        end
      end
    end

    describe '#assign' do
      it 'updates config' do
        subject.assign(transaction_sample_rate: 0.5)
        expect(config.transaction_sample_rate).to eq 0.5
      end

      it 'reverts to previous when missing' do
        subject.assign(transaction_sample_rate: 0.5)
        subject.assign({})
        expect(config.transaction_sample_rate).to eq 1.0
      end

      it 'goes back and forth' do
        subject.assign(transaction_sample_rate: 0.5)
        subject.assign({})
        subject.assign(transaction_sample_rate: 0.5)
        expect(config.transaction_sample_rate).to eq 0.5
      end
    end

    def stub_response(body, **opts)
      stub_request(:post, 'http://localhost:8200/agent/v1/config/')
        .to_return(body: body && body.to_json, **opts)
    end
  end
end
