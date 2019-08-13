# frozen_string_literal: true

module ElasticAPM
  RSpec.describe Error::Exception do
    describe '#initialize' do
      it 'takes an exception and optional attributes' do
        exc = Error::Exception.new ZeroDivisionError.new, message: 'Things'
        expect(exc.message).to eq 'Things'
        expect(exc.type).to eq 'ZeroDivisionError'
      end

      context 'with an exception chain' do
        it 'chains the causes' do
          exc = Error::Exception.new actual_chained_exception,
            message: 'Things'
          expect(exc.message).to eq 'Things'
          expect(exc.type).to eq 'NoMethodError'

          cause1 = exc.cause
          expect(cause1).to be_a Error::Exception
          expect(cause1.message).to eq 'Errno::ENOENT: No such file or ' \
                                           'directory @ rb_sysopen - gotcha'
          expect(cause1.type).to eq 'Errno::ENOENT'

          cause2 = cause1.cause
          expect(cause2).to be_a Error::Exception
          expect(cause2.message).to eq 'ZeroDivisionError: divided by 0'
          expect(cause2.type).to eq 'ZeroDivisionError'
        end
      end
    end
  end
end
