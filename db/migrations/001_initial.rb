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

Sequel.migration do
  up do
    create_table :objects do
      primary_key :id
      String :immutable_id, :null => false, :unique => true
      String :name
      text :additional_info

      time :created_at, :null => false
      time :last_updated_at, :null => false

      index [:immutable_id], :unique => true

    end

    create_table :permission_sets do
      primary_key :id
      String :name, :null => false, :unique => true
      text :additional_info

      time :created_at, :null => false
      time :last_updated_at, :null => false

    end

    create_table :object_permission_set_map do
      primary_key :id
      foreign_key :object_id, :objects
      foreign_key :permission_set_id, :permission_sets

    end

    create_table :permissions do
      primary_key :id
      foreign_key :permission_set_id, :permission_sets
      String :name, :null => false, :unique => true

      time :created_at, :null => false
      time :last_updated_at, :null => false

    end

    create_table :access_control_entries do
      primary_key :id
      foreign_key :object_id, :objects
      foreign_key :permission_id, :permissions
      foreign_key :subject_id, :subjects

      time :created_at, :null => false
      time :last_updated_at, :null => false

      index [:object_id, :permission_id, :subject_id], :unique => true
      index [:object_id, :permission_id]
      index [:object_id]
      index [:subject_id]
    end
    
    create_table :subjects do
      primary_key :id
      String :immutable_id, :null => false, :unique => true
      String :type, :null => false
      foreign_key :object_id, :objects
      text :additional_info

      time :created_at, :null => false
      time :last_updated_at, :null => false

      index [:immutable_id, :type]
      index [:immutable_id], :unique => true
    end

    create_table :members do
      primary_key :id
      foreign_key :group_id, :subjects
      foreign_key :user_id, :subjects

      time :created_at, :null => false
      time :last_updated_at, :null => false

      index [:group_id, :user_id], :unique => true
      index [:group_id]
    end

  end

  down do
    drop_table :members
    drop_table :subjects
    drop_table :access_control_entries
    drop_table :object_permission_set_map
    drop_table :permissions
    drop_table :objects
    drop_table :permission_sets

  end
end
