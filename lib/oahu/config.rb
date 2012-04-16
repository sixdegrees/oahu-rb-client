require 'oahu/version'

module Oahu
  # Defines constants and methods related to configuration
  module Config

    # The HTTP connection adapter that will be used to connect if none is set
    DEFAULT_ADAPTER = :net_http

    # The Faraday connection options if none is set
    DEFAULT_CONNECTION_OPTIONS = {}


    # The client ID if none is set
    DEFAULT_CLIENT_ID = nil

    # The consumer ID if none is set
    DEFAULT_CONSUMER_ID = nil

    # The consumer secret if none is set
    DEFAULT_CONSUMER_SECRET = nil

    # The endpoint that will be used to connect if none is set
    #
    DEFAULT_ENDPOINT = 'https://app.oahu.fr'

    # The oauth token if none is set
    DEFAULT_OAUTH_TOKEN = nil

    # The oauth token secret if none is set
    DEFAULT_OAUTH_TOKEN_SECRET = nil

    DEFAULT_CACHE_STORE = nil

    
    # The value sent in the 'User-Agent' header if none is set
    DEFAULT_USER_AGENT = "Oahu Ruby Gem #{Oahu::VERSION}"

    # An array of valid keys in the options hash when configuring a {Oahu::Client}
    VALID_OPTIONS_KEYS = [
      :adapter,
      :connection_options,
      :client_id, 
      :consumer_id,
      :consumer_secret,
      :endpoint,
      :user_agent,
      :cache_store
    ]

    attr_accessor *VALID_OPTIONS_KEYS

    # When this module is extended, set all configuration options to their default values
    def self.extended(base)
      base.reset
    end

    # Convenience method to allow configuration options to be set in a block
    def configure
      yield self
      self
    end

    # Create a hash of options and their values
    def options
      options = {}
      VALID_OPTIONS_KEYS.each{|k| options[k] = send(k)}
      options
    end

    # Reset all configuration options to defaults
    def reset
      self.adapter            = DEFAULT_ADAPTER
      self.connection_options = DEFAULT_CONNECTION_OPTIONS
      self.client_id          = DEFAULT_CLIENT_ID
      self.consumer_id        = DEFAULT_CONSUMER_ID
      self.consumer_secret    = DEFAULT_CONSUMER_SECRET
      self.endpoint           = DEFAULT_ENDPOINT
      self.user_agent         = DEFAULT_USER_AGENT
      self.cache_store        = DEFAULT_CACHE_STORE
      self
    end

  end
end