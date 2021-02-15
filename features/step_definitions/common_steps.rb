After do
  log "stopping agent"
  @agent&.stop
end

Given('an agent') do
  @agent = ElasticAPM.start
end
