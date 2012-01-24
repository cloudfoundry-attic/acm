require 'sinatra/base'

module ACM::Controller

  class ApiController < Sinatra::Base

    get '/permission_sets/:name' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
      @logger.debug("GET request for /permission_sets/#{params[:name]}")

      response = @permission_set_service.read_permission_set(params[:name])
      @logger.debug("Response is #{response.inspect}")

      response
    end

    post '/permission_sets' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      @logger.debug("POST request for /permission_sets")

      request_json = nil
      begin
        request_json = Yajl::Parser.new.parse(request.body)
      rescue => e
        @logger.error("Invalid request #{e.message}")
        raise ACM::InvalidRequest.new("Invalid character in json request")
      end
      @logger.debug("request is #{request_json.inspect}")

      if(request_json.nil?)
        @logger.error("Invalid request")
        raise ACM::InvalidRequest.new("Request is empty")
      end

      #parse the request
      name = request_json[:name.to_s]
      permissions = request_json[:permissions.to_s]
      additional_info = request_json[:additionalInfo.to_s]

      if(!permissions.nil? && !permissions.kind_of?(Array))
        @logger.error("Invalid request. Permissions must be an arrary")
        raise ACM::InvalidRequest.new("Permissions in the input must be an array")
      end

      ps_json = @permission_set_service.create_permission_set(:name => name,
                                                              :additional_info => additional_info,
                                                              :permissions => permissions)

      @logger.debug("Response is #{ps_json.inspect}")

      #Set the Location response header
      ps = Yajl::Parser.parse(ps_json, :symbolize_keys => true)
      request_url = request.url
      if(request_url.end_with? ["/"])
        request_url.chop()
      end
      headers "Location" => "#{request_url}/#{ps[:name]}"

      ps_json
    end

  end

end
