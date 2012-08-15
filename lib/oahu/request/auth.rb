require 'digest/md5'

module Oahu
  module Request
    class Auth  < Faraday::Middleware

      def call(env)
        sig_time   = Time.now.to_i
        signature  = Digest::MD5.hexdigest [sig_time, @auth_sig_id, @credentials[:consumer_secret]].join("-")
        env[:request_headers]["Oahu-App-Id"]                 = @credentials[:app_id]
        env[:request_headers]["Oahu-#{@auth_strategy}-Id"]   = @auth_id
        env[:request_headers]["Oahu-#{@auth_strategy}-Sig"]  = [sig_time, @auth_sig_id, signature].join("|")
        @app.call(env)
      end

      def initialize(app, credentials, auth)
        @app, @credentials = app, credentials
        @auth_strategy, @auth_id, @auth_sig_id = auth
      end

    end
  end
end