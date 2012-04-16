require 'digest/md5'

module Oahu
  module Request
    class Auth  < Faraday::Middleware

      def call(env)
        sig_time   = Time.now.to_i
        signature  = Digest::MD5.hexdigest [sig_time, @credentials[:client_id], @credentials[:consumer_secret]].join("-")
        env[:request_headers]['Oahu-Consumer-Id']   = @credentials[:consumer_id]
        env[:request_headers]['Oahu-Consumer-Sig']  = [sig_time, @credentials[:client_id], signature].join("|")
        @app.call(env)
      end

      def initialize(app, credentials)
        @app, @credentials = app, credentials
      end

    end
  end
end