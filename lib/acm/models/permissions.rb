require 'sequel'

module ACM::Models
  class Permissions < Sequel::Model(:permissions)

    many_to_one :permission_set, :class => :PermissionSets

  end
end