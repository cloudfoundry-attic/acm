require 'acm/models/acm_common_model'
require 'sequel'

module ACM::Models
  class Permissions < Sequel::Model(:permissions)

    many_to_one :permission_set, :class => "ACM::Models::PermissionSets"

    include ACM::Models::Common

  end
end