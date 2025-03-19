---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/getting-started-rack.html
---

# Getting started with Rack [getting-started-rack]

Add the gem to your `Gemfile`:

```ruby
gem 'elastic-apm'
```

Create a file `config/elastic_apm.yml`:

```yaml
server_url: http://localhost:8200
secret_token: ''
```

Include the middleware, start (and stop) Elastic APM when booting your app:

```ruby
# config.ru

app = lambda do |env|
  [200, {'Content-Type' => 'text/plain'}, ['ok']]
end

# Wraps all requests in transactions and reports exceptions
use ElasticAPM::Middleware

# Start an instance of the Agent
ElasticAPM.start(service_name: 'NothingButRack')

run app

# Gracefully stop the agent when process exits.
# Makes sure any pending transactions are sent.
at_exit { ElasticAPM.stop }
```


## Sinatra example [getting-started-sinatra]

```ruby
# Example config.ru

require 'sinatra/base'

class MySinatraApp < Sinatra::Base
  use ElasticAPM::Middleware

  # ...
end

# Takes optional ElasticAPM::Config values
ElasticAPM.start(app: MySinatraApp, ...)

# You can also do the following, which is equivalent to the above:
# ElasticAPM::Sinatra.start(MySinatraApp, ...)

run MySinatraApp

at_exit { ElasticAPM.stop }
```


## Grape example [getting-started-grape]

```ruby
# Example config.ru

require 'grape'

module Twitter
  class API < Grape::API
    use ElasticAPM::Middleware

  # ...
  end
end

# Start the agent and hook in your app
ElasticAPM::Grape.start(Twitter::API, config)

run Twitter::API
```

