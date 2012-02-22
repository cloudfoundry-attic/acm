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

require 'acm/services/acm_service'
require 'acm/models/objects'
require 'acm/models/permission_sets'

module ACM::Services

  class ObjectService < ACMService

    def initialize
      super

      @user_service = ACM::Services::UserService.new()
      @group_service = ACM::Services::GroupService.new()
    end

    def create_object(opts = {})
      @logger.debug("create object parameters #{opts}")

      permission_sets = get_option(opts, :permission_sets)
      name = get_option(opts, :name)
      additional_info = get_option(opts, :additional_info)
      acl = get_option(opts, :acl)

      o = ACM::Models::Objects.new(
        :name => name,
        :additional_info => additional_info
      )

      ACM::Config.db.transaction do

        begin
          o.save

          #Get the requested permission sets and add them to the object
          if(!permission_sets.nil?)
            #Convert all the entries to strings (otherwise the query fails)
            permission_set_string_values = permission_sets.map do |permission_set_entry|
              permission_set_entry.to_s
            end
            @logger.debug("permission_set_string_values requested for object #{o.inspect} are #{permission_set_string_values.inspect}")

            permission_set_entities = ACM::Models::PermissionSets.filter(:name => permission_set_string_values).all()
            @logger.debug("permission_set_entities are #{permission_set_entities.inspect}")

            permission_set_entities.each { |permission_set_entity|
              @logger.debug("permission set entity #{permission_set_entity.inspect}")
              o.add_permission_set(permission_set_entity)
            }

            @logger.debug("permission_set_string_values for object #{o.id} are #{permission_set_string_values.inspect}")

          end

          @logger.debug("Acls requested are #{acl.inspect}")
          if(!acl.nil?)
            #ACLs are a list of hashes
            acl.each { |permission, user_id_set|
              if(user_id_set.kind_of?(Array))
                user_id_set.each { |user_id|
                  begin
                    subject = get_subject(user_id)
                    #TODO: icky code. should allow a set of permissions to be accepted... later
                    add_permission(o.immutable_id, permission, subject[:id])
                  rescue => e
                    @logger.error("Failed to add permission #{permission.inspect} on object #{o.immutable_id} for user #{user_id} #{e.backtrace}")
                    raise ACM::InvalidRequest.new("Failed to add permission #{permission} on object #{o.immutable_id} for user #{user_id}")
                  end
                }
              else
                @logger.error("Failed to add permission #{permission.inspect} on object #{o.immutable_id}. User id must be an array")
                raise ACM::InvalidRequest.new("Failed to add permission #{permission} on object #{o.immutable_id}. User id must be an array")
              end
            }

          end

        rescue => e
          @logger.error("Failed to create an object #{e}")
          @logger.debug("Failed to create an object #{e.backtrace.inspect}")
          if (e.kind_of?(ACM::ACMError))
            raise e
          else
            raise ACM::SystemInternalError.new(e)
          end
        end

      end

      @logger.debug("Object created is #{o.inspect}")

      o.to_json
    end

    def update_object(opts = {})
      @logger.debug("update object parameters #{opts.inspect}")

      obj_id = get_option(opts, :id)
      permission_sets = get_option(opts, :permission_sets)
      name = get_option(opts, :name)
      additional_info = get_option(opts, :additional_info)
      acl = get_option(opts, :acl)

      if(obj_id.nil?)
        @logger.error("No id provided for the update")
        raise ACM::InvalidRequest.new("Empty object id")
      end

      object = ACM::Models::Objects.filter(:immutable_id => obj_id).first()

      if(object.nil?)
        @logger.error("Could not find object with id #{obj_id.inspect}")
        raise ACM::ObjectNotFound.new("#{obj_id.inspect}")
      else
        @logger.debug("Found object #{object.inspect}")
      end

      ACM::Config.db.transaction do
        object[:name] = name
        object[:additional_info] = additional_info

        begin
          object.remove_all_access_control_entries()
          object.remove_all_permission_sets()

          #Get the requested permission sets and adds them to the object
          if(!permission_sets.nil?)
            #Convert all the entries to strings (otherwise the query fails)
            permission_set_string_values = permission_sets.map do |permission_set_entry|
              permission_set_entry.to_s
            end
            @logger.debug("permission_set_string_values requested for object #{object.inspect} are #{permission_set_string_values.inspect}")

            permission_set_entities = ACM::Models::PermissionSets.filter(:name => permission_set_string_values).all()
            @logger.debug("permission_set_entities are #{permission_set_entities.inspect}")

            permission_set_entities.each { |permission_set_entity|
              @logger.debug("permission set entity #{permission_set_entity.inspect}")
              object.add_permission_set(permission_set_entity)
            }

            @logger.debug("permission_set_string_values for object #{object.id} are #{permission_set_string_values.inspect}")

          end

          @logger.debug("Acls requested are #{acl.inspect}")
          if(!acl.nil?)
            #ACLs are a list of hashes
            acl.each { |permission, user_id_set|
              if(user_id_set.kind_of?(Array))
                user_id_set.each { |user_id|
                  begin
                    subject = get_subject(user_id)
                    add_permission(object.immutable_id, permission, subject[:id])
                  rescue => e
                    @logger.error("Failed to add permission #{permission.inspect} on object #{object.immutable_id} for user #{user_id}")
                    raise ACM::InvalidRequest.new("Failed to add permission #{permission} on object #{object.immutable_id} for user #{user_id}")
                  end
                }
              else
                @logger.error("Failed to add permission #{permission.inspect} on object #{object.immutable_id}. User id must be an array")
                raise ACM::InvalidRequest.new("Failed to add permission #{permission} on object #{object.immutable_id}. User id must be an array")
              end
            }

          end

        rescue => e
          @logger.error("Failed to update object #{e}")
          @logger.debug("Failed to update object #{e.backtrace.inspect}")
          if (e.kind_of?(ACM::ACMError))
            raise e
          else
            raise ACM::SystemInternalError.new(e)
          end
        end

        object.save()
      end

      object = ACM::Models::Objects.filter(:id => object.id).first()
      @logger.debug("Updated object is #{object.inspect}")
      object.to_json
    end

    def get_subject(subject_id)
      subject = nil
      if(subject_id.index("u-") == 0)
        #search for the user. if the user does not exist create it
        subject_id = subject_id.sub(/(u-)/, '')
        user_json = nil
        begin
          user_json = @user_service.find_user(subject_id)
        rescue => e
          if(e.kind_of?(ACM::ObjectNotFound))
            @logger.error("Could not find user #{subject_id}.")
            raise e
          else
            @logger.error("Internal error #{e.message}")
            raise ACM::SystemInternalError.new()
          end
        end

        subject = Yajl::Parser.parse(user_json, :symbolize_keys => true)
      elsif(subject_id.index("g-") == 0)
        #search for the group. If the group does not exist, error out
        group_id = subject_id.sub(/(g-)/, '')
        group_json = nil
        begin
          group_json = @group_service.find_group(group_id)
        rescue => e
          if(e.kind_of?(ACM::ObjectNotFound))
            @logger.error("Could not find group #{group_id} #{e.message}")
            raise e
          else
            @logger.error("Internal error #{e.message}")
            raise ACM::SystemInternalError.new()
          end
        end

        subject = Yajl::Parser.parse(group_json, :symbolize_keys => true)
      end

      subject
    end

    def add_subjects_to_ace(obj_id, permissions, subject_id)

      if(subject_id.nil?)
        @logger.error("Empty subject id")
        raise ACM::InvalidRequest.new()
      end

      subject = get_subject(subject_id)

      object = nil
      if(permissions.respond_to?(:each))
        ACM::Config.db.transaction do
          permissions.each { |permission|
            object = add_permission(obj_id, permission, subject[:id])
          }
        end
      else
        object = add_permission(obj_id, permissions, subject[:id])
      end

      object
    end

    def add_permission(obj_id, permission, user_id)
      @logger.debug("adding permission #{permission} on object #{obj_id} and user #{user_id}")

      #TODO: Get this done in a single update query
      #Find the object
      object = ACM::Models::Objects.filter(:immutable_id => obj_id.to_s).first()
      @logger.debug("requested object #{object.inspect}")
      if(object.nil?)
        @logger.error("Could not find object #{obj_id.to_s}")
        raise ACM::ObjectNotFound.new("Could not find object #{obj_id}")
      end

      #Find the requested permission only if it belongs to a permission set that is related to that object
      requested_permission = ACM::Models::Permissions.join(:permission_sets, :id => :permission_set_id)
                                                    .join(:object_permission_set_map, :permission_set_id => :id)
                                                    .filter(:object_permission_set_map__object_id => object.id)
                                                    .filter(:permissions__name => permission.to_s)
                                                    .select(:permissions__id, :permissions__name)
                                                    .first()
      @logger.debug("requested permission #{requested_permission.inspect}")

      if(requested_permission.nil?)
        @logger.error("Failed to add permission #{permission} on object #{obj_id} for user #{user_id}. Could not find requested permission #{permission}")
        raise ACM::InvalidRequest.new("Failed to add permission #{permission} on object #{obj_id} for user #{user_id}")
      end

      #find the subject
      subject = ACM::Models::Subjects.filter(:immutable_id => user_id.to_s).first()
      @logger.debug("requested subject #{subject.inspect}")
      if(subject.nil?)
        @logger.error("Could not find subject #{user_id.to_s}")
        raise ACM::InvalidRequest.new("Could not find subject #{user_id.to_s}")
      end

      ACM::Config.db.transaction do
        #find the ace for that object and permission
        object_aces = object.access_control_entries.select{|ace| ace.permission_id == requested_permission.id && ace.subject_id == subject.id}
        ace = nil
        if(object_aces.size() == 0)
          ace = object.add_access_control_entry(:object_id => object.id,
                                               :permission_id => requested_permission.id,
                                               :subject_id => subject.id)
          @logger.debug("new ace #{ace.inspect}")
        else
          ace = object_aces[0]
          @logger.debug("found ace #{ace.inspect}")
        end

        @logger.debug("ace count object #{object.id} are #{ACM::Models::AccessControlEntries.filter(:object_id => object.id).count().inspect}")
      end

      object.to_json
    end

    def remove_subjects_from_ace(obj_id, permissions, subject_id)

      user_json = @user_service.find_user(subject_id)
      if(user_json.nil?)
        @logger.error("Failed to find the subject #{subject_id}")
        raise ACM::ObjectNotFound.new("Subject #{subject_id}")
      else
        @logger.debug("Found subject #{user_json.inspect}")
      end
      subject = Yajl::Parser.parse(user_json, :symbolize_keys => true)

      object = nil
      if(permissions.respond_to?(:each))
        ACM::Config.db.transaction do
          permissions.each { |permission|
            object = remove_permission(obj_id, permission, subject[:id])
          }
        end
      else
        object = remove_permission(obj_id, permissions, subject[:id])
      end

      object
    end

    def remove_permission(obj_id, permission, user_id)
      @logger.debug("removing permission #{permission} on object #{obj_id} from user #{user_id}")

      #TODO: Get this done in a single update query
      #Find the object
      object = ACM::Models::Objects.filter(:immutable_id => obj_id.to_s).first()
      @logger.debug("requested object #{object.inspect}")
      if(object.nil?)
        @logger.error("Could not find object #{obj_id.to_s}")
        raise ACM::ObjectNotFound.new("Object #{obj_id}")
      end

      #Find the requested permission only if it belongs to a permission set that is related to that object
      requested_permission = ACM::Models::Permissions.join(:permission_sets, :id => :permission_set_id)
                                                    .join(:object_permission_set_map, :permission_set_id => :id)
                                                    .filter(:object_permission_set_map__object_id => object.id)
                                                    .filter(:permissions__name => permission.to_s)
                                                    .select(:permissions__id, :permissions__name)
                                                    .first()
      @logger.debug("requested permission #{requested_permission.inspect}")

      if(requested_permission.nil?)
        @logger.error("Failed to remove permission #{permission} on object #{obj_id} for user #{user_id}. Could not find permission #{permission}")
        raise ACM::InvalidRequest.new("Failed to remove permission #{permission} on object #{obj_id} for user #{user_id}")
      end

      #find the subject
      subject = ACM::Models::Subjects.filter(:immutable_id => user_id.to_s).first()
      @logger.debug("requested subject #{subject.inspect}")
      if(subject.nil?)
        @logger.error("Could not find subject #{user_id.to_s}")
        raise ACM::InvalidRequest.new("Could not find subject #{user_id.to_s}")
      end

      ACM::Config.db.transaction do
        ace_to_be_deleted = object.access_control_entries.select{|ace| ace.permission_id == requested_permission.id && ace.subject_id == subject.id}.first()
        
        @logger.debug("ace_to_be_deleted #{ace_to_be_deleted.inspect}")

        if(ace_to_be_deleted.nil?)
          @logger.error("Could not find an access control entry for that object and permission matching the subject requested")
          raise ACM::InvalidRequest.new("Could not find an access control entry for the object #{object.name} and permission #{requested_permission.name}")
        else
          ace_to_be_deleted.destroy()
        end

        @logger.debug("ace count for object #{object.id} are #{ACM::Models::AccessControlEntries.filter(:object_id => object.id).count().inspect}")
      end
      
      object = ACM::Models::Objects.filter(:id => object.id).first()
      object.to_json
    end

    def remove_subjects_from_ace(obj_id, permissions, subject_id)

      user_json = @user_service.find_user(subject_id)
      if(user_json.nil?)
        @logger.error("Failed to find the subject #{subject_id}")
        raise ACM::ObjectNotFound.new("Subject #{subject_id}")
      else
        @logger.debug("Found subject #{user_json.inspect}")
      end
      subject = Yajl::Parser.parse(user_json, :symbolize_keys => true)

      object = nil
      if(permissions.respond_to?(:each))
        ACM::Config.db.transaction do
          permissions.each { |permission|
            object = remove_permission(obj_id, permission, subject[:id])
          }
        end
      else
        object = remove_permission(obj_id, permissions, subject[:id])
      end

      object
    end

    def remove_permission(obj_id, permission, user_id)
      @logger.debug("removing permission #{permission} on object #{obj_id} from user #{user_id}")

      #TODO: Get this done in a single update query
      #Find the object
      object = ACM::Models::Objects.filter(:immutable_id => obj_id.to_s).first()
      @logger.debug("requested object #{object.inspect}")
      if(object.nil?)
        @logger.error("Could not find object #{obj_id.to_s}")
        raise ACM::ObjectNotFound.new("Object #{obj_id}")
      end

      #Find the requested permission only if it belongs to a permission set that is related to that object
      requested_permission = ACM::Models::Permissions.join(:permission_sets, :id => :permission_set_id)
                                                    .join(:object_permission_set_map, :permission_set_id => :id)
                                                    .filter(:object_permission_set_map__object_id => object.id)
                                                    .filter(:permissions__name => permission.to_s)
                                                    .select(:permissions__id, :permissions__name)
                                                    .first()
      @logger.debug("requested permission #{requested_permission.inspect}")

      if(requested_permission.nil?)
        @logger.error("Failed to remove permission #{permission} on object #{obj_id} for user #{user_id}. Could not find permission #{permission}")
        raise ACM::InvalidRequest.new("Failed to remove permission #{permission} on object #{obj_id} for user #{user_id}")
      end

      #find the subject
      subject = ACM::Models::Subjects.filter(:immutable_id => user_id.to_s).first()
      @logger.debug("requested subject #{subject.inspect}")
      if(subject.nil?)
        @logger.error("Could not find subject #{user_id.to_s}")
        raise ACM::InvalidRequest.new("Could not find subject #{user_id.to_s}")
      end

      ACM::Config.db.transaction do
        ace_to_be_deleted = object.access_control_entries.select{|ace| ace.permission_id == requested_permission.id && ace.subject_id == subject.id}.first()
        
        @logger.debug("ace_to_be_deleted #{ace_to_be_deleted.inspect}")

        if(ace_to_be_deleted.nil?)
          @logger.error("Could not find an access control entry for that object and permission matching the subject requested")
          raise ACM::InvalidRequest.new("Could not find an access control entry for the object #{object.name} and permission #{requested_permission.name}")
        else
          ace_to_be_deleted.destroy()
        end

        @logger.debug("ace count for object #{object.id} are #{ACM::Models::AccessControlEntries.filter(:object_id => object.id).count().inspect}")
      end
      
      object = ACM::Models::Objects.filter(:id => object.id).first()
      object.to_json
    end

    def read_object(obj_id)
      @logger.debug("read_object parameters #{obj_id.inspect}")
      object = ACM::Models::Objects.filter(:immutable_id => obj_id).first()

      if(object.nil?)
        @logger.error("Could not find object with id #{obj_id.inspect}")
        raise ACM::ObjectNotFound.new("#{obj_id.inspect}")
      else
        @logger.debug("Found object #{object.inspect}")
      end

      object.to_json()
    end

    def delete_object(obj_id)
      @logger.debug("delete_object parameters #{obj_id.inspect}")
      object = ACM::Models::Objects.filter(:immutable_id => obj_id).first()

      if(object.nil?)
        @logger.error("Could not find object with id #{obj_id.inspect}")
        raise ACM::ObjectNotFound.new("#{obj_id.inspect}")
      else
        @logger.debug("Found object #{object.inspect}")
      end

      ACM::Config.db.transaction do
        object.remove_all_permission_sets

        aces = object.access_control_entries
        object.remove_all_access_control_entries

        object.delete
      end

      nil
    end

    def get_users_for_object(obj_id)
      @logger.debug("get_users_for_object parameters #{obj_id.inspect}")
      object = ACM::Models::Objects.filter(:immutable_id => obj_id).first()

      user_permission_entries = {}
      acl = object.access_control_entries
      if(!acl.nil?)
        acl.each { |ace|
          permission = ace.permission.name
          subject = ace.subject
          if(subject.type == :user.to_s)
            subject = subject.immutable_id
            user_permission_entry = user_permission_entries[subject]
            if(!user_permission_entry.nil?)
              if(!user_permission_entry.include? permission)
                user_permission_entry.insert(0, permission)
              end
            else
              user_permission_entry = [permission]
            end
            user_permission_entries[subject] = user_permission_entry
          else
            group_id = subject.immutable_id
            members = ACM::Models::Members.filter(:group_id => subject.id).all().map { |member|
              subject = member.user.immutable_id
              user_permission_entry = user_permission_entries[subject]
              if(!user_permission_entry.nil?)
                if(!user_permission_entry.include? permission)
                  user_permission_entry.insert(0, permission)
                end
              else
                user_permission_entry = [permission]
              end
              user_permission_entries[subject] = user_permission_entry
            }
          end
        }
      end

      user_permission_entries
    end

  end

end
