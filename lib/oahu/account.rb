require 'faraday_middleware/response/parse_xml'

module Oahu
  class Account
    
    attr_reader :id 

    def initialize id
      @id = id
    end

    def event action, data={}, ctx={}
      data['action'] = action
      Oahu.post("/events", { event: { data: data, ctx: ctx } }, request_opts)
    end

    def fetch
      Oahu.get("/me", {}, request_opts)
    end

    def update_player attrs
      Oahu.put("/player", attrs, request_opts)
    end

    def like oid, ctx={}
      event "like", { object_id: oid }, ctx
    end

    def add_image source, opts={}
      opts.symbolize_keys!
      opts[:filename] ||= File.basename(source)
      res = upload source, filename: opts[:filename]
      puts "Upload ok : #{res.inspect}"
      puts "Event opts: #{opts.inspect}"
      event "add_image", opts
    end

    def upload source, opts={}
      return false unless File.exist?(source)

      params = upload_policy['params'] rescue nil
      return false unless params

      filename = opts[:filename]
      filename = File.basename(source) if filename.blank?
      content_type = opts[:content_type] || MIME::Types.type_for(source).first.content_type

      params["Content-Type"]  = content_type
      params["Filename"]      = filename
      params["key"].gsub!("${filename}", "/#{filename}")
      params["name"]          = filename
      params["file"]          = Faraday::UploadIO.new(source, content_type)
      upload_connection.post("/", params).body
    end

    protected

    def upload_policy
      @upload_policy ||= fetch['upload_policy'] rescue nil
    end

    def upload_connection(options={})
      default_options = {
        :headers => {},
        :ssl => {:verify => false},
        :url => upload_policy['url'],
        :timeout => 10,
        :proxy => options.fetch(:proxy, Oahu.proxy),
        :open_timeout => 10
      }
      @upload_connection ||= Faraday.new(default_options.deep_merge(options)) do |builder|
        builder.use Faraday::Request::Multipart
        builder.use Faraday::Request::UrlEncoded
        builder.use Faraday::Response::RaiseError
        builder.use FaradayMiddleware::ParseXml
        builder.adapter(:net_http)
      end
    end

    def request_opts
      { auth: ['account', @id, @id] }
    end

  end
end