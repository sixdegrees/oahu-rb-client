require 'oahu/core_ext/hash'
require 'oahu/client'
require 'oahu/config'
require 'oahu/account'

module Oahu
  extend Config
  class << self
    # Alias for Oahu::Client.new
    #
    # @return [Oahu::Client]
    def new(options={})
      Oahu::Client.new(options)
    end

    # Delegate to Oahu::Client
    def method_missing(method, *args, &block)
      return super unless new.respond_to?(method)
      new.send(method, *args, &block)
    end

    def respond_to?(method, include_private=false)
      new.respond_to?(method, include_private) || super(method, include_private)
    end

    def log msg, level=:debug
      Oahu.logger.send(level.to_sym, "[Oahu:#{Oahu.domain}] #{msg}") if Oahu.logger && Oahu.logger.respond_to?(level.to_sym)
    end
  end

end
