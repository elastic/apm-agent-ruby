# frozen_string_literal: true

# @api private
module Helpers
  def current_transaction
    @agent&.current_transaction
  end

  def current_span
    @agent&.current_span
  end
end

World(Helpers)

When('the agent instruments requests to a server') do
end

When('the agent instruments requests to an external service') do
end

When('a request is made to the server') do
  @agent.start_transaction
end

When('a request is made to an external service') do
  @agent.start_span
end

When('the http status code in the server\'s response is {int}') do |http_status_code|
  current_transaction&.outcome =
    ElasticAPM::Transaction::Outcome.from_http_status(http_status_code)
end

When('the http status code in the external service\'s response is {int}') do |http_status_code|
  current_span&.outcome =
      ElasticAPM::Span::Outcome.from_http_status(http_status_code)
end

Then('the transaction outcome is {string}') do |outcome|
  current_transaction.outcome == outcome
end

Then('the transaction outcome is not set') do
  current_transaction.outcome.nil?
end

Then('the span outcome is {string}') do |outcome|
  current_span.outcome == outcome
end

Then('the span outcome is not set') do
  current_span.outcome.nil?
end

When('there is no http status code in the server\'s response') do
end

When('there is no http status code in the external service\'s response') do
end
