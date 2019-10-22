# frozen_string_literal: true

%w[endpoint_run].each do |lib|
  require "elastic_apm/normalizers/grape/#{lib}"
end
