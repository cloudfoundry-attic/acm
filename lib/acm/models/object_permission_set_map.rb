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

require 'sequel'

module ACM::Models
  class ObjectPermissionSetMap < Sequel::Model(:object_permission_set_map)

    many_to_one :permission_set, :class => "ACM::Models::PermissionSets"
    many_to_one :object, :class => "ACM::Models::Objects"

  end
end