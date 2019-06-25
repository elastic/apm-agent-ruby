# frozen_string_literal: true

module ElasticAPM
  module Transport
    RSpec.describe Connection::ProxyPipe do
      describe '.pipe' do
        it 'returns a reader and a writer' do
          begin
            rd, wr = described_class.pipe

            expect(rd).to respond_to(:each)
            expect(rd).to respond_to(:read)
            expect(wr).to respond_to(:write)

            expect(rd).to respond_to(:close)
            expect(wr).to respond_to(:close)
          ensure
            wr&.close
          end
        end

        it 'pipes from one to the other' do
          rd, wr = described_class.pipe(compress: false)
          ran = false

          thread = Thread.new do
            Thread.stop

            expect(rd.read).to eq "1\n2\n3\n"
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
      end
    end
  end
end
