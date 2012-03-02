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

require 'sinatra/base'

module ACM::Controller

  class ApiController < Sinatra::Base

    get '/groups/:group_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      response = @group_service.find_group(params[:group_id])

      response
    end

    delete '/groups/:group_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      @group_service.delete_group(params[:group_id])
    end

    post '/groups' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

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
      additional_info = request_json[:additional_info.to_s]

      group_json = @group_service.create_group(:id => id,
                                              :additional_info => additional_info,
                                              :members => members)

      #Set the Location response header
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)
      request_url = request.url
      if(request_url.end_with? ["/"])
        request_url.chop()
      end
      headers "Location" => "#{request_url}/#{group[:id]}"

      group_json
    end

    put '/groups/:group_id' do 
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

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
      additional_info = request_json[:additional_info.to_s]

      group_json = @group_service.update_group(:id => id,
                                               :additional_info => additional_info,
                                               :members => members)

      #Set the Location response header
      group = Yajl::Parser.parse(group_json, :symbolize_keys => true)
      request_url = request.url
      if(request_url.end_with? ["/"])
        request_url.chop()
      end
      headers "Location" => "#{request_url}"

      group_json

    end

    put '/groups/:group_id/members/:user_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      updated_group = @group_service.add_user_to_group(params[:group_id], params[:user_id])

      @logger.debug("Updated group #{updated_group.inspect}")
      parsed_group = Yajl::Parser.parse(updated_group, :symbolize_keys => true)
      headers "Location" => "#{request.scheme}://#{request.host_with_port}/groups/#{parsed_group[:id]}"

      updated_group
    end

    delete '/groups/:group_id/members/:user_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      updated_group = @group_service.remove_user_from_group(params[:group_id], params[:user_id])

      @logger.debug("Updated group #{updated_group.inspect}")
      parsed_group = Yajl::Parser.parse(updated_group, :symbolize_keys => true)
      headers "Location" => "#{request.scheme}://#{request.host_with_port}/groups/#{parsed_group[:id]}"

      updated_group
    end
  end

end
