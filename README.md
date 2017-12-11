# ElasticAPM

This is the official Rubygem for adding [Elastic][]'s [APM][] to your Ruby app.

## Setup

Add the gem to your `Gemfile`:

```ruby
gem 'elastic-apm'
```

### Optional: Configure the agent

```ruby
Rails.application.configure do |config|
  config.elastic_apm.server_url = 'https://somewhere.else'
end
```

If you're using Rails the gem automatically inserts itself where it needs to be, but it supports any Rack compatible app eg. Sinatra:

```ruby
# config.ru

require 'sinatra/base'

ElasticAPM.start # Takes an optional ElasticAPM::Config

class App < Sinatra::Base
  use ElasticAPM::Middleware
  
  # ...
end

run App

at_exit { ElasticAPM.stop }
```

[Elastic]: https://elastic.co
[APM]: https://www.elastic.co/guide/en/apm/server/index.html
