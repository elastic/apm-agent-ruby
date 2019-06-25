# frozen_string_literal: true

module ExceptionHelpers
  def actual_exception
    1 / 0
  rescue => e # rubocop:disable Style/RescueStandardError
    e
  end
end
