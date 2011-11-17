require 'sequel'

module ACM::Models
  class Members < Sequel::Model(:members)

    many_to_one :users, :class_name => :Subjects

  end
end