---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/context.html
---

# Adding additional context [context]


## Adding custom context [_adding_custom_context]

You can add your own custom, nested JSON-compatible data to the current transaction using `ElasticAPM.set_custom_context(hash)` eg.:

```ruby
class ThingsController < ApplicationController
  before_action do
    ElasticAPM.set_custom_context(company: current_user.company)
  end

  # ...
end
```


## Adding labels [_adding_labels]

Labels are special in that they are indexed in your Elasticsearch database and therefore queryable.

```ruby
ElasticAPM.set_label(:company_name, 'Acme, Inc.')
```

Note that `.`, `*` and `"` in keys are converted to `_`.


## Providing info about the user [_providing_info_about_the_user]

You can provide ElasticAPM with info about the current user.

```ruby
class ApplicationController < ActionController::Base
  before_action do
    current_user && ElasticAPM.set_user(current_user)
  end
end
```

