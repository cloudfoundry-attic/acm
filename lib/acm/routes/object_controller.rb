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
require 'json'

module ACM::Controller

  class ApiController < Sinatra::Base

    get '/objects/:object_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      response = @object_service.read_object(params[:object_id])

      response
    end

    get '/objects/:object_id/users' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      response = @object_service.get_users_for_object(params[:object_id])

      response.to_json
    end

    delete '/objects/:object_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      @object_service.delete_object(params[:object_id])
    end

    post '/objects' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

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
      permission_sets = request_json[:permission_sets.to_s]
      additional_info = request_json[:additional_info.to_s]
      acl = request_json[:acl.to_s]

      object_json = @object_service.create_object(:name => name,
                                                :additional_info => additional_info,
                                                :permission_sets => permission_sets,
                                                :acl => acl)

      #Set the Location response header
      object = Yajl::Parser.parse(object_json, :symbolize_keys => true)
      request_url = request.url
      if request_url.end_with? ["/"]
        request_url.chop()
      end
      headers "Location" => "#{request_url}/#{object[:id]}"

      object_json
    end

    put '/objects/:object_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      if params[:object_id].nil?
        @logger.error("Empty object id")
        raise ACM::InvalidRequest.new("Empty object id")
      end

      name = nil
      permission_sets = nil
      additional_info = nil
      acl = nil

      if !request.body.nil? && request.body.size > 0
        request_json = nil
        begin
          request_json = Yajl::Parser.new.parse(request.body)
        rescue => e
          @logger.error("Invalid request #{e.message}")
          raise ACM::InvalidRequest.new("Invalid character in json request")
        end
        @logger.debug("request is #{request_json.inspect}")

        #parse the request
        name = request_json[:name.to_s]
        permission_sets = request_json[:permission_sets.to_s]
        additional_info = request_json[:additional_info.to_s]
        acl = request_json[:acl.to_s]
      end

      object_json = @object_service.update_object(:id => params[:object_id],
                                                  :name => name,
                                                  :additional_info => additional_info,
                                                  :permission_sets => permission_sets,
                                                  :acl => acl)

      #Set the Location response header
      object = Yajl::Parser.parse(object_json, :symbolize_keys => true)
      request_url = request.url
      if request_url.end_with? ["/"]
        request_url.chop()
      end
      headers "Location" => "#{request_url}"

      object_json
    end


    #Add permission(s) for a subject to an object's acl
    put '/objects/:object_id/acl' do
      # PUT /objects/*object_id*/acl?id=*subject*&p=*permission1*,*permission2*
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      permissions_request = params[:p].split(',')
      @logger.debug("Permissions requested #{permissions_request.inspect}")

      object_json = @object_service.add_subjects_to_ace(params[:object_id], permissions_request, params[:id])

      @logger.debug("Modified object #{object_json.inspect}")

      #Set the Location response header
      object = Yajl::Parser.parse(object_json, :symbolize_keys => true)
      headers "Location" => "#{request.scheme}://#{request.host_with_port}/objects/#{object[:id]}"

      object_json
    end

    #Remove permissions for a subject from an object's acl
    delete '/objects/:object_id/acl' do 
      # DELETE /objects/*object_id*/acl?id=*subject*&p=*permission1*,*permission2*
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      permissions_request = params[:p].split(',')
      @logger.debug("Permissions requested to be removed are #{permissions_request.inspect}")

      subject = params[:id]
      if subject.start_with?("u-") || subject.start_with?("g-")
        subject = subject[2..subject.length]
        @logger.debug("Stripping subject of prefix #{subject}")
      end

      object_json = @object_service.remove_subjects_from_ace(params[:object_id], permissions_request, subject)

      @logger.debug("Modified object #{object_json.inspect}")

      #Set the Location response header
      object = Yajl::Parser.parse(object_json, :symbolize_keys => true)
      headers "Location" => "#{request.scheme}://#{request.host_with_port}/objects/#{object[:id]}"

      object_json
    end

  end

end
