# frozen_string_literal: true

%w[
    action_controller
    action_mailer
    action_view
    active_record
  ].each do |lib|
    require "elastic_apm/normalizers/rails/#{lib}"
  end
