Feature: Api Key

  Scenario: An api key is set in the Authorization header as a base64 encoded string
    When an api key is set to 'E3q29W4BmlaQDpZqVAif:yOpkmzvFQ9SyO54ChjIcgg' in the config
    Then the Authorization header includes api key as a Base64 encoded string

  Scenario: An configured api key is sent in the Authorization header
    When an api key is set in the config
    Then the api key is sent in the Authorization header

  Scenario: An configured api key take precedence over a secret token
    When an api key is set in the config
    When a secret_token is set in the config
    Then the api key is sent in the Authorization header

  Scenario: A configured secret token is sent if no api key is configured
    When a secret_token is set in the config
    When an api key is not set in the config
    Then the secret token is sent in the Authorization header
