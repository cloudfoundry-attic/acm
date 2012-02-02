require 'sinatra/base'
require 'json'

module ACM::Controller

  class ApiController < Sinatra::Base

    get '/objects/:object_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
      @logger.debug("GET request for /objects/#{params[:object_id]}")

      response = @object_service.read_object(params[:object_id])
      @logger.debug("Response is #{response.inspect}")

      response
    end

    get '/objects/:object_id/users' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
      @logger.debug("GET request for /objects/#{params[:object_id]}/users")

      response = @object_service.get_users_for_object(params[:object_id])
      @logger.debug("Response is #{response.inspect}")

      response.to_json
    end

    delete '/objects/:object_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
      @logger.debug("DELETE request for /objects/#{params[:object_id]}")

      @object_service.delete_object(params[:object_id])
    end

    post '/objects' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
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
      additional_info = request_json[:additional_info.to_s]
      acl = request_json[:acl.to_s]

      object_json = @object_service.create_object(:name => name,
                                                :additional_info => additional_info,
                                                :permission_sets => permission_sets,
                                                :acl => acl)

      @logger.debug("Response is #{object_json.inspect}")

      #Set the Location response header
      object = Yajl::Parser.parse(object_json, :symbolize_keys => true)
      request_url = request.url
      if(request_url.end_with? ["/"])
        request_url.chop()
      end
      headers "Location" => "#{request_url}/#{object[:id]}"

      object_json
    end

    put '/objects/:object_id' do
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
      @logger.debug("PUT request for /objects/#{params[:object_id]}")

      if(params[:object_id].nil?)
        @logger.error("Empty object id")
        raise ACM::InvalidRequest.new("Empty object id")
      end

      name = nil
      permission_sets = nil
      additional_info = nil
      acl = nil

      if(!request.body.nil? && request.body.size > 0)
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

      @logger.debug("Response is #{object_json.inspect}")

      #Set the Location response header
      object = Yajl::Parser.parse(object_json, :symbolize_keys => true)
      request_url = request.url
      if(request_url.end_with? ["/"])
        request_url.chop()
      end
      headers "Location" => "#{request_url}"

      object_json
    end


    #Add permission(s) for a subject to an object's acl
    put '/objects/:object_id/acl' do
      # PUT /objects/*object_id*/acl?id=*subject*&p=*permission1*,*permission2*
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version
      @logger.debug("PUT request for /objects/#{params[:object_id]}/acl Params are #{params.inspect}")

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
      @logger.debug("DELETE request for /objects/#{params[:object_id]}/acl Params are #{params.inspect}")

      permissions_request = params[:p].split(',')
      @logger.debug("Permissions requested to be removed are #{permissions_request.inspect}")

      subject = params[:id]
      if(subject.start_with?("u-") || subject.start_with?("g-"))
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
