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

      group = ACM::Models::Subjects.new(
        :immutable_id => !opts[:id].nil? ? opts[:id] : SecureRandom.uuid(),
        :type => :group.to_s,
        :additional_info => !opts[:additional_info].nil? ? opts[:additional_info] : nil
      )

      ACM::Config.db.transaction do
        begin
          existing_group = ACM::Models::Subjects.filter(:immutable_id => group.immutable_id).first()
          if(existing_group.nil?)
            group.save
          else
            @logger.error("Group id #{existing_group.immutable_id} already used")
            raise ACM::InvalidRequest.new("Group id #{existing_group.immutable_id} already used")
          end

          if(!opts[:members].nil?)
            members = opts[:members]
            if(members.kind_of?(Array))
              members.each {|member|
                if(!member.nil?)
                  begin
                    user = ACM::Models::Subjects.filter(:immutable_id => member).first()
                    if(user.nil?)
                      @logger.error("Could not find user #{member}.")
                      raise ACM::ObjectNotFound.new("User #{member}")
                    end
                    group.add_member(:user_id => user.id)
                  end
                end
              }
            else
              @logger.error("Failed to create group. members must be an array")
              raise ACM::InvalidRequest.new("Failed to create group. members must be an array")
            end
          end
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

      if(opts[:id].nil?)
        @logger.error("Empty group id to update")
        raise ACM::InvalidRequest.new("Empty group id")
      end

      group = ACM::Models::Subjects.filter(:immutable_id => opts[:id], :type => :group.to_s).first()

      if(group.nil?)
        @logger.error("Could not find group with id #{group_id.inspect}")
        raise ACM::ObjectNotFound.new("#{group_id.inspect}")
      else
        @logger.debug("Found group #{group.inspect}")
      end
      
      begin
        ACM::Config.db.transaction do
          group[:additional_info] = opts[:additional_info]
          group.remove_all_members()
          if(!opts[:members].nil?)
            members = opts[:members]
            if(members.kind_of?(Array))
              members.each {|member|
                if(!member.nil?)
                  begin
                    user = ACM::Models::Subjects.filter(:immutable_id => member).first()
                    if(user.nil?)
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

      group = ACM::Models::Subjects.filter(:immutable_id => opts[:id], :type => :group.to_s).first()
      group.to_json()
    end


    # finds the group given the group id
    # @params group_id - Group id
    # @returns the group as json
    def find_group(group_id)
      @logger.debug("find_group parameters #{group_id.inspect}")
      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if(group.nil?)
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
      @logger.debug("find_group parameters #{group_id.inspect} #{user_id}")
      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if(group.nil?)
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
      if(group_members.nil? || group_members.size() == 0)
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
      @logger.debug("remove_user_from_group parameters #{group_id.inspect} #{user_id.inspect}")
      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if(group.nil?)
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
        member = ACM::Models::Members.filter(:user_id => user.id).first()
        @logger.debug("User is a member #{member.inspect}")
      rescue => e
        @logger.error("Internal error #{e.message}")
        raise ACM::SystemInternalError.new()
      end

      group.remove_member(member)

      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()
      @logger.debug("Updated group #{group.inspect}")
      group.to_json
    end


    # adds a user to a group
    # @params group_id - Id of the group to be deleted
    # @returns nothing
    def delete_group(group_id)
      @logger.debug("delete parameters #{group_id.inspect}")
      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if(group.nil?)
        @logger.error("Could not find group with id #{group_id.inspect}")
        raise ACM::ObjectNotFound.new("#{group_id.inspect}")
      else
        @logger.debug("Found group #{group.inspect}")
      end

      ACM::Config.db.transaction do
        group_members = group.members
        group_members.each { |group_member|
          group_member.delete
        }

        group.remove_all_access_control_entries

        #TODO: Delete the associated object

        group.delete
        nil
      end
    end

  end

end
