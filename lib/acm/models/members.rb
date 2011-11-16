require 'sequel'

module ACM::Models
  class Members < Sequel::Model(:members)

    many_to_one :group, :class_name => "Groups"

  end
end