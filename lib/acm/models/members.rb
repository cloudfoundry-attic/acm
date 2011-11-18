require 'sequel'

module ACM::Models
  class Members < Sequel::Model(:members)

    many_to_one :users, :class => "ACM::Models::Subjects"

  end
end