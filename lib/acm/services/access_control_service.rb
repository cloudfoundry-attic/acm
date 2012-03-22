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
require 'acm/models/objects'
require 'acm/models/permissions'

module ACM::Services

  class AccessControlService < ACMService

    def check_access(object_id, subject_id, permissions)
      @logger.debug("Request to check_access #{object_id} #{subject_id} #{permissions}")

      if subject_id.nil?
        @logger.debug("Subject is nil")
        raise ACM::ObjectNotFound.new("")
      end

      if permissions.nil? || permissions.size() == 0
        @logger.debug("No permissions")
        raise ACM::ObjectNotFound.new("")
      else
        unless permissions.kind_of?(Array) #The code below only works with arrays
          permissions = [permissions]
        end
      end

      #Find the object
      object = ACM::Models::Objects.filter(:immutable_id => object_id).select(:id).first()
      @logger.debug("Object #{object.inspect}")

      if object.nil?
        @logger.debug("Could not find the object #{object_id}")
        raise ACM::ObjectNotFound.new("")
      end

      #Find the permission entities that need to be checked
      permission_ids = ACM::Models::Permissions.filter(:name => permissions).select(:id).all().map{|p| p.id}
      #All the permissions must exist. That's why the size of the input must match the size of the permissions query
      if permission_ids.nil? || permission_ids.size() == 0 || permission_ids.size() < permissions.size()
        @logger.debug("Permissions did not match #{permission_ids.inspect} #{permissions.inspect} #{permission_ids.size()} #{permissions.size()}")
        raise ACM::ObjectNotFound.new("")
      end
      @logger.debug("Permission Ids #{permission_ids.inspect}")

      #Find the aces for the object and each permission
      permission_ids.each { |permission_id|
        acl = ACM::Models::AccessControlEntries.filter(:object_id => object.id,
                                                       :permission_id => permission_id).all()
        if acl.nil? || acl.size() == 0
          @logger.debug("ACL did not match")
          raise ACM::ObjectNotFound.new("")
        end
        @logger.debug("ACL #{acl.inspect}")

        found = false
        acl.each { |ace| #Go through each ace
          @logger.debug("Ace #{ace.inspect} Searching for #{subject_id}")

          subject = ace.subject #Search the subject for each ace
          @logger.debug("Subject being checked #{subject.inspect}")
          if subject.type == :user.to_s
            #If the subject has not already been found and we have a match, return a true
            found = (found == false && subject.immutable_id.eql?(subject_id.to_s)) ? true : false
            @logger.debug("Subject #{subject.inspect} found #{found}")
          else                              #If the subject is a group, find the members
            group_id = subject.immutable_id
            found = (found == false && group_id.eql?(subject_id.to_s)) ? true : false
            @logger.debug("Subject #{subject.inspect} found #{found}")

            #If the group was not the subject being searched for, search the members
            unless found
              ACM::Models::Members.filter(:group_id => subject.id).all().each { |member|
                found = (found == false && member.user.immutable_id.eql?(subject_id.to_s)) ? true : false
                @logger.debug("Subject #{member.user.inspect} found #{found}")
                if found
                  break
                end
              }
            end
          end

          #Don't go any further in this search if the subject has already been found
          if found
            break
          end
        }
        unless found  #If the acl does not contain the subject, the operation fails
          @logger.debug("No matching subjects for acl #{acl.inspect}")
          raise ACM::ObjectNotFound.new("")
        end
      }
      @logger.info("Access OK")
    end

  end
end
