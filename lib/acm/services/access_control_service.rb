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
require 'acm/models/objects'
require 'acm/models/permissions'

module ACM::Services

  class AccessControlService < ACMService

    def check_access(object_id, subject_id, permissions)
      object = ACM::Models::Objects.filter(:immutable_id => object_id).select(:id).first() unless object_id.nil?
      if object.nil?
        raise ACM::ObjectNotFound.new("#{object_id}")
      else
        @logger.debug("Object #{object.inspect}")
      end

      subject = ACM::Models::Subjects.filter(:immutable_id => subject_id).first() unless subject_id.nil?

      if subject.nil?
        raise ACM::ObjectNotFound.new("#{subject_id}")
      else
        @logger.debug("Subject #{subject.inspect}")
      end

      if permissions.nil? || permissions.size() == 0
        @logger.debug("No permissions")
        raise ACM::ObjectNotFound.new("")
      else
        unless permissions.kind_of?(Array) #The code below only works with arrays
          permissions = [permissions]
        end
      end

      subject_ids = []
      if subject.type == "group"
        # Find members of that group
        members = ACM::Models::Members.filter(:group_id => subject.id).all().map{|member| member.user_id}
        subject_ids += members unless members.nil?
      else
        subject_ids = [subject.id]
      end

      # For each subject, find the groups that the subject is a member of
      unless subject_ids.size() == 0
        group_ids = ACM::Models::Members.join(:subjects, :id => :user_id)
                                        .filter(:members__user_id => subject_ids)
                                        .select(:group_id)
                                        .all().map{|member| member.group_id}
        @logger.debug("Groups that the user is a member of #{group_ids}")
        subject_ids += group_ids unless group_ids.nil?
      end

      @logger.debug("subject_ids = #{subject_ids}")

      distinct_permission_ids = ACM::Models::AccessControlEntries.join(:permissions, :id => :access_control_entries__permission_id)
                                               .filter(:permissions__name => permissions)
                                               .filter(:access_control_entries__object_id => object.id)
                                               .filter(:subject_id => subject_ids)
                                               .distinct()
                                               .select(:permission_id)
                                               .all() unless subject_ids.size() == 0

      @logger.debug("Distinct Permission ids #{distinct_permission_ids.inspect}")

      raise ACM::ObjectNotFound.new("") if distinct_permission_ids.nil? || permissions.size() != distinct_permission_ids.size()
      @logger.info("Access OK")
    end
  end
end
