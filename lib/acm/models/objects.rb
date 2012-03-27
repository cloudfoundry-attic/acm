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

require 'acm/models/acm_common_model'
require 'acm/models/permission_sets'
require 'acm/models/access_control_entries'

require 'sequel'
require 'yajl'

module ACM::Models
  class Objects < Sequel::Model(:objects)

    many_to_many :permission_sets,
                 :left_key => :object_id, :right_key => :permission_set_id,
                 :join_table => :object_permission_set_map,
                 :class => "ACM::Models::PermissionSets"

    one_to_many   :access_control_entries, :key => :object_id, :class => "ACM::Models::AccessControlEntries"

    include ACM::Models::Common

    def before_create
      super
      set_immutable_id
    end

    def set_immutable_id
      self.immutable_id = SecureRandom.uuid()
      @logger.debug("Immutable id for object #{self.name} is #{self.immutable_id}")
    end

    def to_json
      begin
        @logger.debug("Object Id #{self.id}")
        #Get the names out of the permission sets
        o_permission_sets = ACM::Models::PermissionSets.join(:object_permission_set_map, :permission_set_id => :id)
                                                       .filter(:object_id => self.id)
                                                       .select(:permission_sets__name)
                                                       .all().map{|permission_set| permission_set.name}
        object_types = nil
        if !o_permission_sets.nil? && o_permission_sets.size() > 0
          object_types = o_permission_sets
        end

        output_object = {
          :name => self.name,
          :permission_sets => object_types,
          :id => self.immutable_id,
          :additional_info => self.additional_info,
        }

        output_object[:acl] = {}
        o_acl = ACM::Models::AccessControlEntries.join(:permissions, :id => :permission_id)
                                                 .join(:subjects, :id => :access_control_entries__subject_id)
                                                 .filter(:access_control_entries__object_id => self.id)
                                                 .select(:permissions__name, :subjects__immutable_id, :subjects__type)
                                                 .all()
        @logger.debug("Access control entries for this object #{o_acl.inspect}")
        o_acl.each { |access_control_entry|
          @logger.debug("Access Control entry #{access_control_entry.inspect}")
          permission_name = access_control_entry[:name]
          @logger.debug("Permission name #{permission_name.inspect}")
          subject = access_control_entry[:immutable_id]
          @logger.debug("Subject #{subject.inspect}")
          subject_immutable_id = nil
          if access_control_entry[:type].to_sym == :user
            subject_immutable_id = "#{subject}"
          else
            subject_immutable_id = "g-#{subject}"
          end

          output_object[:acl][permission_name].nil? ? 
                      output_object[:acl][permission_name] = [subject_immutable_id] : 
                      output_object[:acl][permission_name].insert(0, subject_immutable_id)
        }

        @logger.debug("ACL hash for object #{self.id} is #{output_object[:acl].inspect}")

        output_object.update(
          :meta => {
            :created => self.created_at,
            :updated => self.last_updated_at,
            :schema => latest_schema
          }
        )

        output_object.to_json()
      rescue => e
        @logger.error("Failure in object.to_json #{e.inspect}")
        throw e
      end
    end
  end
end
