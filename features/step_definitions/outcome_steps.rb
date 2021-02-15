Given('an active span') do
  ElasticAPM.start_transaction("test-transaction-#{Time.now.to_i}")
  @span = ElasticAPM.start_span("test-span-#{Time.now.to_i}")
end

Given('user sets span outcome to {string}') do |outcome|
  @span.outcome = outcome
end

Given('span terminates with outcome {string}') do |outcome|
  if outcome == 'success'
    ElasticAPM.end_span
  end
end

Then('span outcome is {string}') do |outcome|
  @span.outcome == outcome
end

Given('an active transaction') do
  @transaction = ElasticAPM.start_transaction('cucumber-test-transaction')
end

Given('user sets transaction outcome to {string}') do |outcome|
  @transaction.outcome = outcome
end

Given('transaction terminates with outcome {string}') do |outcome|
  if outcome == 'success'
    ElasticAPM.end_transaction
  end
end

Then('transaction outcome is {string}') do |outcome|
  @transaction.outcome == outcome
end

Given('span terminates with an error') do
  begin
    ElasticAPM.with_span("test-span-#{Time.now.to_i}") do |span|
      @span = span
      raise Exception
    end
  rescue Exception
  end
end

Given('span terminates without error') do
  ElasticAPM.with_span("test-span-#{Time.now.to_i}") do |span|
    @span = span
  end
end

Given('transaction terminates with an error') do
  ElasticAPM.end_transaction
  begin
    ElasticAPM.with_transaction("test-transaction-#{Time.now.to_i}") do |transaction|
      @transaction = transaction
      raise Exception
    end
  rescue Exception
  end
end

Given('transaction terminates without error') do
  ElasticAPM.end_transaction
  ElasticAPM.with_transaction("test-transaction-#{Time.now.to_i}") do |transaction|
    @transaction = transaction
  end
end

Given('an HTTP transaction with {int} response code') do |response_code|
  @transaction = ElasticAPM.start_transaction("test-transaction-#{Time.now.to_i}")
  @transaction.outcome =
    ElasticAPM::Transaction::Outcome.from_http_status(response_code)
end

Given('an HTTP span with {int} response code') do |response_code|
  @span = ElasticAPM.start_span("test-span-#{Time.now.to_i}")
  @span.outcome =
    ElasticAPM::Span::Outcome.from_http_status(response_code)
end