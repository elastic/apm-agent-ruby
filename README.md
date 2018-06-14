# elastic-apm
## Elastic APM agent for ♦️Ruby

[![Jenkins](https://img.shields.io/jenkins/s/https/apm-ci.elastic.co/job/elastic+apm-agent-ruby+master.svg)](https://apm-ci.elastic.co/job/elastic+apm-agent-ruby+master/) [![Gem](https://img.shields.io/gem/v/elastic-apm.svg)](https://rubygems.org/gems/elastic-apm)

The official Rubygem for [Elastic][] [APM][].

**🚧 NB:** The current version of the agent is `1.0.0.beta1`. This means we're really close to `1.0.0`. The API is stable and the only remaining thing to do is testing. Thank you if you've already been testing the agent!

To test the prerelease:

```sh
gem install elastic-apm --pre
```

or in your `Gemfile`:

```ruby
gem 'elastic-apm', '~> 1.0.0.beta1'
```

💡 We'd love to get feedback and information about you setup – please answer this [☑ short survey](https://goo.gl/forms/LQktvn4rkLWBNSWy1).

---

## Documentation

[Full documentation at Elasti.co](https://www.elastic.co/guide/en/apm/agent/ruby/index.html).

<ul>
<li><a href="https://www.elastic.co/guide/en/apm/agent/ruby/1.x/introduction.html">Introduction</a></li>
<li><a href="https://www.elastic.co/guide/en/apm/agent/ruby/1.x/getting-started-rails.html">Getting started with Rails</a></li>
<li><a href="https://www.elastic.co/guide/en/apm/agent/ruby/1.x/getting-started-rack.html">Getting started with Rack</a></li>
<li><a href="https://www.elastic.co/guide/en/apm/agent/ruby/1.x/configuration.html">Configuration</a></li>
<li>
<a href="https://www.elastic.co/guide/en/apm/agent/ruby/1.x/advanced.html">Advanced Topics</a>
<ul>
<li><a href="https://www.elastic.co/guide/en/apm/agent/ruby/1.x/custom-instrumentation.html">Custom instrumentation</a></li>
<li><a href="https://www.elastic.co/guide/en/apm/agent/ruby/1.x/spies.html">Spies — instrumented libraries</a></li>
</ul>
</li>
<li><a href="https://www.elastic.co/guide/en/apm/agent/ruby/1.x/api.html">Public API</a></li>
</ul>

---

## Getting help

If you find a bug, please [report an issue](https://github.com/elastic/apm-agent-ruby/issues).
For any other assistance, please open or add to a topic on the [APM discuss forum](https://discuss.elastic.co/c/apm).

## License

Apache 2.0

[Elastic]: https://elastic.co
[APM]: https://www.elastic.co/guide/en/apm/server/index.html
