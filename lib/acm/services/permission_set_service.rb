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
          @logger.error("Unknown error #{e}")
          raise ACM::SystemInternalError.new(e)
        end
      end

      @logger.debug("Permission set created is #{ps.inspect}")

      ps.to_json
    end

    def update_permission_set(opts = {})
      @logger.debug("update permission_set parameters #{opts}")

      name = get_option(opts, :name)
      if(name.nil?)
        @logger.error("Failed to update a permission set. No name provided")
        raise ACM::InvalidRequest.new("Missing name for permission set")
      end

      permissions = get_option(opts, :permissions)
      additional_info = get_option(opts, :additional_info)

      ps = ACM::Models::PermissionSets.find(:name => name.to_s).first().first()

      begin
        ACM::Config.db.transaction do
          ps.save

          ps.permissions.each { |existing_permission|
            existing_permission.destroy()
          }

          if(!permissions.nil?)
            permissions.each { |permission|
              ACM::Models::Permissions.new(:permission_set_id => ps.id, :name => permission.to_s).save
            }
          end
        end
      rescue => e
        @logger.error("Failed to update the permission set#{e}")
        @logger.debug("Failed to update the permission set #{e.backtrace.inspect}")
        if (e.kind_of?(ACM::ACMError))
          raise e
        else
          @logger.error("Unknown error #{e}")
          raise ACM::SystemInternalError.new(e)
        end
      end

      @logger.debug("Updated permission set is #{ps.inspect}")

      ps.to_json
    end

    def read_permission_set(name)
      @logger.debug("read_permission_set parameters #{name.inspect}")
      permission_set = ACM::Models::PermissionSets.filter(:name => name.to_s).first()

      if(permission_set.nil?)
        @logger.error("Could not find permission set with id #{name.inspect}")
        raise ACM::ObjectNotFound.new("#{name.inspect}")
      else
        @logger.debug("Found permission set #{permission_set.inspect}")
      end

      permission_set.to_json()
    end

    def add_permission_to_permission_set(permission_set_name, permission)
      @logger.debug("read_permission_set parameters #{permission_set_name}, #{permission}")
      permission_set = ACM::Models::PermissionSets.filter(:name => name.to_s).first()

      if(permission_set.nil?)
        @logger.error("Could not find permission set with id #{name.inspect}")
        raise ACM::ObjectNotFound.new("#{name.inspect}")
      else
        @logger.debug("Found permission set #{permission_set.inspect}")
      end
      
      if(!permission_set.permissions.include? permission)
        #Find which set includes that permission

        #Remove the permission from that set

        #Include it in the new permission set
      end
      
      read_permission_set(permission_set_name)
    end

  end

end
