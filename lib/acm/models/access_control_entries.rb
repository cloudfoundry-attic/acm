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
