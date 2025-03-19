---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/custom-instrumentation.html
---

# Custom instrumentation [custom-instrumentation]

When installed and properly configured, ElasticAPM will automatically wrap your app’s request/responses in transactions and report its errors. It also wraps each background job if you use Sidekiq or DelayedJob.

But it is also possible to create your own transactions as well as provide spans for any automatic or custom transaction.

See [`ElasticAPM.start_transaction`](/reference/api-reference.md#api-agent-start_transaction) and [`ElasticAPM.start_span`](/reference/api-reference.md#api-agent-start_span).


## Helpers [_helpers]

ElasticAPM includes some nifty helpers if you just want to instrument a regular method.

```ruby
class Thing
  include ElasticAPM::SpanHelpers

  def do_the_work
    # ...
  end
  span_method :do_hard_work # takes optional `name` and `type`

  def self.do_all_the_work
    # ...
  end
  span_class_method :do_hard_work, 'Custom name', 'custom.work_thing'
end
```


## Custom span example [_custom_span_example]

If you are already inside a Transaction (most likely) and you want to instrument some work inside it, add a custom span:

```ruby
class ThingsController < ApplicationController
  def index
    @result_of_work = ElasticAPM.with_span "Heavy work" do
      do_the_heavy_work
    end
  end
end
```


## Custom transaction example [_custom_transaction_example]

If you are **not** inside a Transaction already (eg. outside of your common web application) start and manage your own transactions like so:

```ruby
class Something
  def do_work
    transaction = ElasticAPM.start_transaction 'Something#do_work'

    begin
      Sequel[:users] # many third party libs will be automatically instrumented
    rescue Exception => e
      ElasticAPM.report(e)
      raise
    ensure
      ElasticAPM.end_transaction('result')
    end
  end
end
```

**Note:** If the agent isn’t started beforehand this will do nothing. See [ElasticAPM.start](/reference/api-reference.md#api-agent-start).
