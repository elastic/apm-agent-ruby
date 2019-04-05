# frozen_string_literal: true

module ElasticAPM
  module Transport
    RSpec.describe Connection::ProxyPipe do
      describe '.pipe' do
        it 'returns a reader and a writer' do
          rd, wr = described_class.pipe

          expect(rd).to respond_to(:each)
          expect(wr).to respond_to(:write)

          expect(rd).to respond_to(:close)
          expect(wr).to respond_to(:close)
        end

        it 'pipes from one to the other' do
          rd, wr = described_class.pipe
          ran = false

          thread = Thread.new do
            Thread.stop

            expect(rd.read).to eq '123'
            ran = true
          end

          wr.write('1')
          wr.write('2')
          wr.write('3')

          sleep 0.1 while thread.status != 'sleep'

          thread.wakeup
          wr.close
          thread.join

          expect(ran).to be true
        end

        it 'calls callbacks before reading and writing' do
          did_read = double(call: true)

          rd, wr = described_class.pipe(on_first_read: did_read)

          wr.write 'test'

          thread = Thread.new do
            Thread.stop
            expect(rd.readpartial(1024)).to eq 'test'

            expect do
              expect(rd.readpartial(1024)).to eq ''
            end.to raise_error(EOFError)
          end

          sleep 0.1 while thread.status != 'sleep'

          thread.wakeup
          wr.close
          thread.join

          expect(did_read).to have_received(:call).once
        end
      end
    end
  end
end
