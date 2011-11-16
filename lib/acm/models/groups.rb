require 'sequel'

module ACM::Models
  class Groups < Sequel::Model(:groups)

    many_to_one :object, :class_name => :Objects
    one_to_many :members, :class_name => :Members

  end
end