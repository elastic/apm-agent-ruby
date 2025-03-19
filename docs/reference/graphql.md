---
mapped_pages:
  - https://www.elastic.co/guide/en/apm/agent/ruby/current/graphql.html
---

# GraphQL [graphql]

The agent comes with support for GraphQL based APIs.

This slightly alters how transactions are named when they relate to GraphQL queries, so they are easier to tell apart and debug.

To enable GraphQL support, add the included Tracer to your schema:

```ruby
class MySchema < GraphQL::Schema
  # ...

  tracer ElasticAPM::GraphQL # <-- include this
end
```

