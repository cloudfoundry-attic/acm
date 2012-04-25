#--
# Cloud Foundry 2012.02.03 Beta
# Copyright (c) [2009-2012] VMware, Inc. All Rights Reserved. 
# 
# This product is licensed to you under the Apache License, Version 2.0 (the "License").  
# You may not use this product except in compliance with the License.  
# 
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the 
# subcomponent's license, as noted in the LICENSE file. 
#++

require 'sinatra/base'

module ACM::Controller

  class ApiController < Sinatra::Base

    get '/permission_sets/:name' do
      content_type 'application/json', :charset => 'utf-8'

      @permission_set_service.read_permission_set(params[:name])
    end

    post '/permission_sets' do
      content_type 'application/json', :charset => 'utf-8'

      request_json = nil
      begin
        request_json = Yajl::Parser.new.parse(request.body)
      rescue => e
        @logger.error("Invalid request #{e.message}")
        raise ACM::InvalidRequest.new("Invalid character in json request")
      end
      @logger.debug("request is #{request_json.inspect}")

      if request_json.nil?
        @logger.error("Invalid request")
        raise ACM::InvalidRequest.new("Request is empty")
      end

      #parse the request
      name = request_json[:name.to_s]
      permissions = request_json[:permissions.to_s]
      additional_info = request_json[:additional_info.to_s]

      if !permissions.nil? && !permissions.kind_of?(Array)
        @logger.error("Invalid request. Permissions must be an arrary")
        raise ACM::InvalidRequest.new("Permissions in the input must be an array")
      end

      ps_json = @permission_set_service.create_permission_set(:name => name,
                                                              :additional_info => additional_info,
                                                              :permissions => permissions)

      #Set the Location response header
      ps = Yajl::Parser.parse(ps_json, :symbolize_keys => true)
      request_url = request.url
      if request_url.end_with? ["/"]
        request_url.chop()
      end
      headers "Location" => "#{request_url}/#{ps[:name]}"

      ps_json
    end

    put '/permission_sets/:name' do
      content_type 'application/json', :charset => 'utf-8'

      request_json = nil
      begin
        request_json = Yajl::Parser.new.parse(request.body)
      rescue => e
        @logger.error("Invalid request #{e.message}")
        raise ACM::InvalidRequest.new("Invalid character in json request")
      end
      @logger.debug("request is #{request_json.inspect}")

      if request_json.nil?
        @logger.error("Invalid request")
        raise ACM::InvalidRequest.new("Request is empty")
      end

      #parse the request
      name = params[:name]
      permissions = request_json[:permissions.to_s]
      additional_info = request_json[:additional_info.to_s]

      if !permissions.nil? && !permissions.kind_of?(Array)
        @logger.error("Invalid request. Permissions must be an arrary")
        raise ACM::InvalidRequest.new("Permissions in the input must be an array")
      end

      ps_json = @permission_set_service.update_permission_set(:name => name,
                                                              :additional_info => additional_info,
                                                              :permissions => permissions)

      headers "Location" => "#{request.scheme}://#{request.host_with_port}/permission_sets/#{name}"

      ps_json
    end

    delete '/permission_sets/:name' do
      content_type 'application/json', :charset => 'utf-8'

      @permission_set_service.delete_permission_set(params[:name])
    end

  end

end
