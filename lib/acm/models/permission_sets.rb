require 'acm/models/acm_common_model'
require 'sequel'

module ACM::Models
  class PermissionSets < Sequel::Model(:permission_sets)

    many_to_many :objects,
                 :left_key => :permission_set_id, :right_key => :object_id,
                 :join_table => :object_permission_set_map,
                 :class => "ACM::Models::Objects"

    one_to_many  :permissions, :key => :permission_set_id, :class => "ACM:Models::Permissions"

    include ACM::Models::Common

  end
end