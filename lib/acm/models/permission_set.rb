require 'sequel'

module ACM::Models
  class PermissionSet < Sequel::Model(:permission_sets)

    many_to_many :objects,
                 :left_key => :permission_set_id, :right_key => :object_id,
                 :join_table => :object_permission_set_map

  end
end