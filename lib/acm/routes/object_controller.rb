require 'sinatra/base'

module ACM::Controller

  class ApiController < Sinatra::Base

    get '/objects/:object_id' do
      content_type 'application/json', :charset => 'utf-8'
      @logger.debug("GET request for /objects/#{params[:object_id]}")

      response = @object_service.read_object(params[:object_id])
      @logger.debug("Response is #{response.inspect}")

      response
    end

    delete '/objects/:object_id' do
      content_type 'application/json', :charset => 'utf-8'
      @logger.debug("DELETE request for /objects/#{params[:object_id]}")

      @object_service.delete_object(params[:object_id])
    end

    post '/objects' do
      content_type 'application/json', :charset => 'utf-8'
      @logger.debug("POST request for /objects")

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
      permission_sets = request_json[:permission_sets.to_s]
      additional_info = request_json[:additionalInfo.to_s]
      acls = request_json[:acl.to_s]

      object_json = @object_service.create_object(:name => name,
                                                :additional_info => additional_info,
                                                :permission_sets => permission_sets,
                                                :acl => acls)

      @logger.debug("Response is #{object_json.inspect}")
      object_json
    end

  end

end