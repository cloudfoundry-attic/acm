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
require 'sequel'
require 'json'

module ACM::Models
  class PermissionSets < Sequel::Model(:permission_sets)

    many_to_many :objects,
                 :left_key => :permission_set_id, :right_key => :object_id,
                 :join_table => :object_permission_set_map,
                 :class => "ACM::Models::Objects"

    one_to_many  :permissions, :key => :permission_set_id, :class => "ACM::Models::Permissions"

    include ACM::Models::Common

    def to_json()
      @logger.debug("Permission set name #{self.name}")

      permission_set_hash = {
        :name => self.name,
        :additional_info => self.additional_info
      }

      permission_set_hash[:permissions] = []
      self.permissions.each { |permission|
        permission_set_hash[:permissions].insert(0, permission.name)
      }

      permission_set_hash.update(
        :meta => {
          :created => self.created_at,
          :updated => self.last_updated_at,
          :schema => latest_schema
        }
      )

      permission_set_hash.to_json
    end

  end
end
