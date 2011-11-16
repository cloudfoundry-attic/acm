require 'sequel'

module ACM::Models
  class AccessControlEntities < Sequel::Model(:access_control_entities)

    many_to_one :object, :class => :Objects
    many_to_one :permission, :class => :Permissions
    many_to_one :group, :class => :Groups

  end
end