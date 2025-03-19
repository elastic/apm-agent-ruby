---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/getting-started-rails.html
---

# Getting started with Rails [getting-started-rails]


## Setup [_setup]

Add the gem to your `Gemfile`:

```ruby
gem 'elastic-apm'
```

Create a file `config/elastic_apm.yml`:

```yaml
server_url: http://localhost:8200
secret_token: ''
```

Or if you prefer environment variables, skip the file and set `ELASTIC_APM_SERVER_URL` and `ELASTIC_APM_SECRET_TOKEN` in your local or server environment.

This automatically sets up error logging and performance tracking but of course there are knobs to turn if you’d like to. See [*Configuration*](/reference/configuration.md).

