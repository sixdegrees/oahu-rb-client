require 'oahu/config'
require 'oahu/connection'
require 'oahu/request'

module Oahu
  class Client

    attr_accessor *Config::VALID_OPTIONS_KEYS

    include Oahu::Connection
    include Oahu::Request

    # Initializes a new API object
    #
    # @param attrs [Hash]
    # @return [Oahu::Client]
    def initialize(attrs={})
      attrs = Oahu.options.merge(attrs)
      Config::VALID_OPTIONS_KEYS.each do |key|
        instance_variable_set("@#{key}".to_sym, attrs[key])
      end
    end

    def credentials
      {
        :app_id           => app_id,
        :client_id        => client_id,
        :consumer_id      => consumer_id,
        :consumer_secret  => consumer_secret
      }
    end
    
    def app
      return unless consumer_id
      @app ||= get("/app", :app_id => consumer_id)
    end

  end
end