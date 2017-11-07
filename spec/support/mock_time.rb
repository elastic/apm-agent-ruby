# frozen_string_literal: true

RSpec.configure do |config|
  config.around :each, mock_time: true do |example|
    @mocked_date = Time.utc(1992, 1, 1)

    def travel(distance)
      Timecop.freeze(@mocked_date += distance / 1_000.0)
    end

    travel 0
    example.run
    Timecop.return
  end
end
