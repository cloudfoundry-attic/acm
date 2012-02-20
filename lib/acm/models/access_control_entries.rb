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
require 'acm/models/acm_common_model'


module ACM::Models
  class AccessControlEntries < Sequel::Model(:access_control_entries)

    one_to_one :object, :key => :id, :primary_key => :object_id, :class => "ACM::Models::Objects"
    one_to_one :permission, :key => :id, :primary_key => :permission_id, :class => "ACM::Models::Permissions"
    one_to_one :subject, :key => :id, :primary_key => :subject_id, :class => "ACM::Models::Subjects"

    include ACM::Models::Common

  end
end
