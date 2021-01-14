After do
  @agent&.stop
end

Given('an agent') do
  @agent = ElasticAPM.start
end
