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

Sequel.migration do
  up do
    add_index :object_permission_set_map, :object_id
    add_index :object_permission_set_map, :permission_set_id
  end

  down do
    drop_index :object_permission_set_map, :object_id
    drop_index :object_permission_set_map, :permission_set_id
  end
end
