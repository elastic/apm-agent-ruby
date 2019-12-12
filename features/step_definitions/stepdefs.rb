When("an api key is set to {string} in the config") do |string|
  @config ||= ElasticAPM::Config.new
  @config.api_key = string
  @api_key = string
end

Then("the Authorization header includes api key as a Base64 encoded string") do
  headers = ElasticAPM::Transport::Headers.new(@config).to_h
  headers[:Authorization].include?(Base64.strict_encode64(@api_key))
end

When("an api key is set in the config") do
  @config ||= ElasticAPM::Config.new
  @config.api_key = '123:456'
end

Then("the api key is sent in the Authorization header") do
  headers = ElasticAPM::Transport::Headers.new(@config).to_h
  headers[:Authorization].include?(@config.api_key)
end

When("a secret_token is set in the config") do
  @config ||= ElasticAPM::Config.new
  @config.secret_token = 'abcde'
end

When("an api key is not set in the config") do
  @config ||= ElasticAPM::Config.new
end

Then("the secret token is sent in the Authorization header") do
  headers = ElasticAPM::Transport::Headers.new(@config).to_h
  headers[:Authorization].include?(@config.secret_token)
end
