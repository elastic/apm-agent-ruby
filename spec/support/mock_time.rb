# frozen_string_literal: true

RSpec.configure do |config|
  config.before :each, mock_time: true do
    @mocked_date = Time.utc(1992, 1, 1)
    @mocked_clock = 123_000

    def travel(us)
      Timecop.freeze(@mocked_date += (us / 1_000_000.0))
      @mocked_clock += us
    end

    allow(ElasticAPM::Util).to receive(:monotonic_micros) { @mocked_clock }

    travel 0
  end

  config.after :each, mock_time: true do
    Timecop.return
  end
end
