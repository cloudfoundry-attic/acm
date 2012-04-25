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

require 'acm/models/permission_sets'

module ACM::Services

  class PermissionSetService < ACMService

    def create_permission_set(opts = {})
      @logger.debug("create permission_set parameters #{opts}")

      name = get_option(opts, :name)
      if name.nil?
        @logger.error("Failed to create a permission set. No name provided")
        raise ACM::InvalidRequest.new("Missing name for permission set")
      end

      permissions = get_option(opts, :permissions)
      additional_info = get_option(opts, :additional_info)

      ps = ACM::Models::PermissionSets.new(:name => name.to_s, :additional_info => additional_info)

      begin
        ACM::Config.db.transaction do
          ps.save

          unless permissions.nil?
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

    # Full update to the permission set
    # Method does a full replacement of the permission set
    # If a permission requested is new, a new permission will be created
    # If the permission exists but is assigned to another permission set,
    # it will be unassigned from that permission set and assigned to this
    # one.
    # If the permission is being referenced in an object, it must be
    # un-assigned before removal from the set.
    # Input
    #   opts - Hash
    #     :name - string permission set name
    #     :permissions - array of permissions
    #     :additional_info - string additional user defined information
    # 
    def update_permission_set(opts = {})
      @logger.debug("update permission_set parameters #{opts}")

      name = get_option(opts, :name)
      if name.nil?
        @logger.error("Failed to update a permission set. No name provided")
        raise ACM::InvalidRequest.new("Missing name for permission set")
      end

      requested_permissions = get_option(opts, :permissions)
      additional_info = get_option(opts, :additional_info)

      ps = ACM::Models::PermissionSets.find(:name => name.to_s)
      if ps.nil?
        @logger.error("Could not find permission set with name #{name}")
        raise ACM::ObjectNotFound.new(name)
      end

      begin
        ACM::Config.db.transaction do

          ps.additional_info = additional_info
          
          unless requested_permissions.nil?
            #Go through the requested permissions and add them to the permission set
            requested_permissions.each { |requested_permission|
              required_permission = ACM::Models::Permissions.find(:name => requested_permission.to_s)
              
              if required_permission.nil?
                ACM::Models::Permissions.new(:permission_set_id => ps.id, :name => requested_permission.to_s).save
              else
                # Un-assign permissions from an existing set and assign it to the new set
                required_permission.permission_set_id = ps.id
                required_permission.save
              end
            }
          end

          ps.save

          # Remove the permissions that are not requested
          ps.permissions.each { |existing_permission|
            if requested_permissions.nil? || !requested_permissions.to_s.include?(existing_permission.name.to_s)
              begin
                existing_permission.destroy()
              rescue => e
                @logger.error("Failed to remove permission #{existing_permission.name.to_s}. May be referenced elsewhere")
                raise ACM::InvalidRequest.new("Failed to remove permission #{existing_permission.name.to_s}")
              end
            end
          }

          ps.save
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

      ps = ACM::Models::PermissionSets.find(:name => name.to_s)
      @logger.debug("Updated permission set is #{ps.inspect}")

      ps.to_json
    end

    def delete_permission_set(name)
      @logger.debug("delete permission_set #{name}")

      if name.nil?
        @logger.error("Failed to delete permission set. No name provided")
        raise ACM::InvalidRequest.new("Missing name for permission set")
      end

      ps = ACM::Models::PermissionSets.find(:name => name)
      if ps.nil?
        @logger.error("Could not find permission set with name #{name}")
        raise ACM::ObjectNotFound.new(name)
      end

      begin
        ACM::Config.db.transaction do

          # Remove the permissions that are not requested
          ps.permissions.each { |existing_permission|
            begin
              existing_permission.destroy()
            rescue => e
              @logger.error("Failed to remove permission #{existing_permission.name}. May be referenced elsewhere")
              raise ACM::InvalidRequest.new("Failed to remove permission #{existing_permission.name}")
            end
          }

          ps.save
          ps.destroy
        end
      rescue => e
        @logger.error("Failed to delete the permission set#{e}")
        @logger.debug("Failed to delete the permission set #{e.backtrace.inspect}")
        if (e.kind_of?(ACM::ACMError))
          raise e
        else
          @logger.error("Unknown error #{e}")
          raise ACM::SystemInternalError.new(e)
        end
      end

      nil
    end

    def read_permission_set(name)
      @logger.debug("read_permission_set parameters #{name.inspect}")
      permission_set = ACM::Models::PermissionSets.filter(:name => name.to_s).first()

      if permission_set.nil?
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

      if permission_set.nil?
        @logger.error("Could not find permission set with id #{name.inspect}")
        raise ACM::ObjectNotFound.new("#{name.inspect}")
      else
        @logger.debug("Found permission set #{permission_set.inspect}")
      end
      
      unless permission_set.permissions.include? permission
        #Find which set includes that permission

        #Remove the permission from that set

        #Include it in the new permission set
      end
      
      read_permission_set(permission_set_name)
    end

  end

end
