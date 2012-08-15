require 'faraday'
require 'oahu/request/auth'
require 'faraday_middleware/response/parse_json'
require 'faraday_middleware/response/caching'

module Oahu
  module Connection
  private

    # Returns a Faraday::Connection object
    #
    # @param options [Hash] A hash of options
    # @return [Faraday::Connection]
    def connection(options={})
      default_options = {
        :headers => {
          :accept => 'application/json',
          :user_agent => user_agent,
        },
        :ssl => {:verify => false},
        :url => options.fetch(:endpoint, endpoint),
        :timeout => 10,
        :open_timeout => 10
      }
      auth = options[:auth] || ["consumer", consumer_id, client_id]
      @connection ||= Faraday.new(default_options.deep_merge(connection_options)) do |builder|
        builder.use Oahu::Request::Auth, credentials, auth
        builder.use Faraday::Request::UrlEncoded 
        builder.use FaradayMiddleware::Caching, cache_store unless cache_store.nil?
        builder.use FaradayMiddleware::ParseJson
        builder.use Faraday::Response::RaiseError
        builder.adapter(adapter)
      end
    end
  end
end
