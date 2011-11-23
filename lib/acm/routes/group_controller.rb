require 'sinatra/base'

module ACM::Controller

  class ApiController < Sinatra::Base

    get '/groups/:group_id' do
      content_type 'application/json', :charset => 'utf-8'
      @logger.debug("GET request for /groups/#{params[:group_id]}")

      response = @group_service.find_group(params[:group_id])
      @logger.debug("Response is #{response.inspect}")

      response
    end

    delete '/groups/:group_id' do
      content_type 'application/json', :charset => 'utf-8'
      @logger.debug("DELETE request for /groups/#{params[:group_id]}")

      @group_service.delete_group(params[:group_id])
    end

    post '/groups' do
      content_type 'application/json', :charset => 'utf-8'
      @logger.debug("POST request for /groups")

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
      id = request_json[:id.to_s]
      members = request_json[:members.to_s]
      additional_info = request_json[:additionalInfo.to_s]

      group_json = @group_service.create_group(:id => id,
                                              :additional_info => additional_info,
                                              :members => members)

      @logger.debug("Response is #{group_json.inspect}")
      #Set the Location response header
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)
      request_url = request.url
      if(request_url.end_with? ["/"])
        request_url.chop()
      end
      headers "Location" => "#{request_url}/#{group[:id]}"

      group_json
    end

  end

end
