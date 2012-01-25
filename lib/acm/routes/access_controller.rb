require 'sinatra/base'

module ACM::Controller

  class ApiController < Sinatra::Base

    get '/objects/:object_id/access/?' do
      #params ?id=1234&p=read_appspace,write_appspace
      content_type 'application/json', :charset => 'utf-8', :schema => ACM::Config.default_schema_version

      object_id = params[:object_id]
      if(params[:id].nil? || params[:p].nil?)
        @logger.error("check_access empty subject or permissions")
        raise ACM::InvalidRequest.new("Could not find subject or permissions in the request")
      end
      subject_id = params[:id]
      permissions = params[:p].split(',')
      @logger.debug("Access check for object #{object_id} subject #{subject_id} permissions #{permissions.inspect}")

      return_code = 404

      begin
        @access_control_service.check_access(object_id, subject_id, permissions)
        return_code = 200
      rescue => e
        @logger.error("check_access error #{e.message}")
        @logger.debug("check_access error #{e.backtrace}")
        if !e.kind_of?(ACM::ObjectNotFound)
          raise ACM::SystemInternalError.new()
        else
          raise e
        end
      end

      @logger.debug("access check return code #{return_code}")
      return_code
    end

  end
end
