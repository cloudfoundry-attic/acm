require 'acm/models/acm_common_model'
require 'sequel'

module ACM::Models
  class Members < Sequel::Model(:members)

    one_to_one :group, :key => :id, :class => "ACM::Models::Subjects"
    many_to_one :user, :class => "ACM::Models::Subjects"

    include ACM::Models::Common

  end
end