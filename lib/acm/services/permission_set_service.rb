require 'acm/models/permission_sets'

module ACM::Services

  class PermissionSetService < ACMService

    def create_permission_set(opts = {})
      @logger.debug("create permission_set parameters #{opts}")

      name = get_option(opts, :name)
      if(name.nil?)
        @logger.error("Failed to create a permission set. No name provided")
        raise ACM::InvalidRequest.new("Missing name for permission set")
      end

      permissions = get_option(opts, :permissions)
      additional_info = get_option(opts, :additional_info)

      ps = ACM::Models::PermissionSets.new(:name => name.to_s, :additional_info => additional_info)

      begin
        ACM::Config.db.transaction do
          ps.save

          if(!permissions.nil?)
            permissions.each { |permission|
              ACM::Models::Permissions.new(:permission_set_id => ps.id, :name => permission.to_s).save
            }
          end
        end
      rescue => e
        @logger.error("Failed to create a permission set#{e}")
        @logger.debug("Failed to create a permission set #{e.backtrace.inspect}")
        if (e.kind_of?(ACM::ACMError))
          raise e
        else
          raise ACM::SystemInternalError.new(e)
        end
      end

      @logger.debug("Permission set created is #{ps.inspect}")

      ps.to_json
    end

    def get_option(map, key)
      map[key].nil? ? nil : map[key]
    end

  end

end