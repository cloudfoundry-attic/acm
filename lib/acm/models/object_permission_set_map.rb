require 'sequel'

module ACM::Models
  class ObjectPermissionSetMap < Sequel::Model(:object_permission_set_map)

    many_to_one :permission_set, :class => "ACM::Models::PermissionSets"
    many_to_one :object, :class => "ACM::Models::Objects"

  end
end