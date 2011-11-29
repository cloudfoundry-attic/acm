require 'sequel'
require 'acm/models/acm_common_model'


module ACM::Models
  class AccessControlEntries < Sequel::Model(:access_control_entries)

    one_to_one :object, :key => :id, :primary_key => :object_id, :class => "ACM::Models::Objects"
    one_to_one  :permission, :key => :id, :primary_key => :permission_id, :class => "ACM::Models::Permissions"
    many_to_many :subjects,
                 :left_key => :access_control_entry_id, :right_key => :subject_id,
                 :join_table => :ace_subject_map,
                 :class => "ACM::Models::Subjects"

    include ACM::Models::Common

  end
end