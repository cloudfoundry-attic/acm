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

require 'acm/services/acm_service'
require 'acm/models/subjects'
require 'acm/models/members'

module ACM::Services

  class GroupService < ACMService

    def initialize
      super

      @user_service = ACM::Services::UserService.new()
    end

    # Creates a group
    # @param opts
    #     :id => optional group id
    #     :additional_info => additional group information as a string
    #     :members => array of members for the group
    # @returns the group as json
    def create_group(opts = {})
      
      group_id = opts[:id]
      if !group_id.nil? && group_id.start_with?("g-")
        group_id = group_id[2..group_id.length]
      end

      group = ACM::Models::Subjects.new(
        :immutable_id => !group_id.nil? ? group_id : SecureRandom.uuid(),
        :type => :group.to_s,
        :additional_info => !opts[:additional_info].nil? ? opts[:additional_info] : nil
      )

      users = []
      unless opts[:members].nil?
        members = opts[:members]
        if members.kind_of?(Array)
          users = ACM::Models::Subjects.filter(:immutable_id => members).select(:id).all()
          if users.size() != members.size()
            @logger.error("Could not find all the requested users")
            raise ACM::InvalidRequest.new("Could not find all the requested users")
          end
        else
          @logger.error("Failed to create group. members must be an array")
          raise ACM::InvalidRequest.new("Failed to create group. members must be an array")
        end
      end

      ACM::Config.db.transaction do
        begin
          begin
            group.save
          rescue => e
            if e.kind_of?(Sequel::DatabaseError)
              @logger.error("Group id #{group_id} already used")
              raise ACM::InvalidRequest.new("Group id #{group_id} already used")
            else
              raise e
            end
          end

          group_map = []
          users.each { |user|
            group_map << {"group_id" => group.id, 
                          "user_id" => user.id, 
                          "created_at" => Time.now, 
                          "last_updated_at" => Time.now}
          }
          @logger.debug("Group map #{group_map}")
          ACM::Models::Members.dataset.multi_insert(group_map) if group_map.size() > 0

        rescue => e
          if e.kind_of?(ACM::ACMError)
            raise e
          else
            @logger.info("Failed to create a group #{e}")
            @logger.debug("Failed to create a group #{e.backtrace.inspect}")
            raise ACM::SystemInternalError.new()
          end
        end
      end

      group.to_json()
    end

    def update_group(opts = {})
      @logger.debug("update_group parameters #{opts.inspect}")

      if opts[:id].nil?
        @logger.error("Empty group id to update")
        raise ACM::InvalidRequest.new("Empty group id")
      end

      group_id = opts[:id]
      if group_id.start_with?("g-")
        group_id = group_id[2..group_id.length]
      end

      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if group.nil?
        @logger.error("Could not find group with id #{group_id.inspect}")
        raise ACM::ObjectNotFound.new("#{group_id.inspect}")
      else
        @logger.debug("Found group #{group.inspect}")
      end
      
      begin
        ACM::Config.db.transaction do
          group[:additional_info] = opts[:additional_info]
          group.remove_all_members()
          unless opts[:members].nil?
            members = opts[:members]
            if members.kind_of?(Array)
              members.each {|member|
                unless member.nil?
                  begin
                    user = ACM::Models::Subjects.filter(:immutable_id => member).first()
                    if user.nil?
                      @logger.error("Could not find user #{member}.")
                      raise ACM::ObjectNotFound.new("User #{member}")
                    end
                    group.add_member(:user_id => user.id)
                  end
                end
              }
            else
              @logger.error("Failed to update the group. members must be an array")
              raise ACM::InvalidRequest.new("Failed to update the group. members must be an array")
            end
          end

          group.save
        end
      rescue => e
        if e.kind_of?(ACM::ACMError)
          raise e
        else
          @logger.info("Failed to update a group #{e}")
          @logger.debug("Failed to update a group #{e.backtrace.inspect}")
          raise ACM::SystemInternalError.new()
        end
      end

      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()
      group.to_json()
    end


    # finds the group given the group id
    # @params group_id - Group id
    # @returns the group as json
    def find_group(group_id)
      @logger.debug("find_group parameters #{group_id.inspect}")

      if !group_id.nil? && group_id.start_with?("g-")
        group_id = group_id[2..group_id.length]
      end

      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if group.nil?
        @logger.error("Could not find group with id #{group_id.inspect}")
        raise ACM::ObjectNotFound.new("#{group_id.inspect}")
      else
        @logger.debug("Found group #{group.inspect}")
      end

      group.to_json()
    end


    # adds a user to a group
    # @params group_id - Group id
    # @params user_id - Id of the user to be added
    # @returns the modified group as json
    def add_user_to_group(group_id, user_id)
      if !group_id.nil? && group_id.start_with?("g-")
        group_id = group_id[2..group_id.length]
      end

      @logger.debug("find_group parameters #{group_id.inspect} #{user_id}")
      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if group.nil?
        @logger.error("Could not group user with id #{group_id.inspect}")
        raise ACM::ObjectNotFound.new("#{group_id.inspect}")
      else
        @logger.debug("Found group #{group.inspect}")
      end

      user = nil
      begin
        user = ACM::Models::Subjects.filter(:immutable_id => user_id, :type => :user.to_s).first()
        @logger.debug("Found user to be added #{user.inspect}")
      rescue => e
        @logger.error("Internal error #{e.message}")
        raise ACM::SystemInternalError.new()
      end

      if (user.nil?)
        @logger.error("Could not find user #{user_id}")
        raise ACM::ObjectNotFound.new("User #{user_id}")
      end

      #Is the user already a member of the group?
      group_members = group.members_dataset.filter(:user_id => user.id).all()
      @logger.debug("Existing group members #{group_members.inspect}")
      if group_members.nil? || group_members.size() == 0
        user = ACM::Models::Subjects.filter(:immutable_id => user_id, :type => :user.to_s).first()
        @logger.debug("new user #{user.id} group #{group.id}")
        group.add_member(:user_id => user.id)
      end

      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()
      @logger.debug("Updated group #{group.inspect}")
      group.to_json
    end

    # removes a user from a group
    # @params group_id - Group id
    # @params user_id - Id of the user to be added
    # @returns the modified group as json
    def remove_user_from_group(group_id, user_id)
      if !group_id.nil? && group_id.start_with?("g-")
        group_id = group_id[2..group_id.length]
      end

      @logger.debug("remove_user_from_group parameters #{group_id.inspect} #{user_id.inspect}")
      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if group.nil?
        @logger.error("Could not group user with id #{group_id.inspect}")
        raise ACM::ObjectNotFound.new("#{group_id.inspect}")
      else
        @logger.debug("Found group #{group.inspect}")
      end

      user = nil
      begin
        user = ACM::Models::Subjects.filter(:immutable_id => user_id, :type => :user.to_s).first()
        @logger.debug("Found user to be removed #{user.inspect}")
      rescue => e
        @logger.error("Internal error #{e.message}")
        raise ACM::SystemInternalError.new()
      end

      if (user.nil?)
        @logger.debug("Could not find user #{user_id}. Creating the user")
        raise ACM::ObjectNotFound.new("User #{user_id}")
      end

      member = nil
      begin
        member = ACM::Models::Members.filter(:group_id => group.id).filter(:user_id => user.id).first()
        @logger.debug("User is a member #{member.inspect}")
      rescue => e
        @logger.error("Internal error #{e.message}")
        raise ACM::SystemInternalError.new()
      end

      member.delete

      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()
      @logger.debug("Updated group #{group.inspect}")
      group.to_json
    end

    def delete_group(group_id)
      if !group_id.nil? && group_id.start_with?("g-")
        group_id = group_id[2..group_id.length]
      end

      @logger.debug("delete parameters #{group_id.inspect}")
      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if group.nil?
        @logger.error("Could not find group with id #{group_id.inspect}")
        raise ACM::ObjectNotFound.new("#{group_id.inspect}")
      else
        @logger.debug("Found group #{group.inspect}")
      end

      group_members = group.members
      acls = group.access_control_entries()
      @logger.debug("Acls for group #{group.immutable_id} are #{acls.inspect}")

      ACM::Config.db.transaction do
        group_members.each { |group_member|
          group_member.destroy()
        }

        acls.each { |acl|
          acl.destroy()
        }

        #TODO: Delete the associated object

        group.delete
        nil
      end
    end

  end

end
