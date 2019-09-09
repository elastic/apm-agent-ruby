# frozen_string_literal: true

module ExceptionHelpers
  def actual_exception
    1 / 0
  rescue => e # rubocop:disable Style/RescueStandardError
    e
  end

  class One < StandardError; end
  class Two < StandardError; end
  class Three < StandardError; end

  # rubocop:disable Metrics/MethodLength
  def actual_chained_exception
    raise Three
  rescue Three
    begin
      raise Two
    rescue Two
      begin
        raise One
      rescue One => e
        e
      end
    end
  end
  # rubocop:enable Metrics/MethodLength
end
