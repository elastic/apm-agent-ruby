# frozen_string_literal: true

module ExceptionHelpers
  def actual_exception
    1 / 0
  rescue => e # rubocop:disable Style/RescueStandardError
    e
  end

  # rubocop:disable Metrics/MethodLength
  def actual_chained_exception
    1 / 0
  rescue ZeroDivisionError
    begin
      File.open('gotcha')
    rescue Errno::ENOENT
      begin
        [].merge
      rescue NoMethodError => e
        e
      end
    end
  end
  # rubocop:enable Metrics/MethodLength
end
