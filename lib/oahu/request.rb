module Oahu
  # Defines HTTP request methods
  module Request
    # Perform an HTTP DELETE request
    def delete(path, params={}, options={})
      request(:delete, api_path(path), params, options)
    end

    # Perform an HTTP GET request
    def get(path, params={}, options={})
      request(:get, api_path(path), params, options)
    end

    # Perform an HTTP POST request
    def post(path, params={}, options={})
      request(:post, api_path(path), params, options)
    end

  private

    def api_path path
      "/api/v1/clients/#{credentials[:client_id]}/#{path.gsub(/^\//, '')}"
    end

    # Perform an HTTP request
    def request(method, path, params, options)
      response = connection(options).run_request(method, nil, nil, nil) do |request|
        # request.options[:phoenix] = true if options[:phoenix]
        request.options[:raw] = true if options[:raw]
        case method.to_sym
        when :delete, :get
          request.url(path, params)
        when :post
          request.path = path
          request.body = params unless params.empty?
        end
      end
      options[:raw] ? response : response.body
    end

  end
end
