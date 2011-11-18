require 'acm/models/acm_common_model'
require 'sequel'

module ACM::Models
  class Permissions < Sequel::Model(:permissions)

    many_to_one :permission_set, :class => "ACM::Models::PermissionSets"
    one_to_many :access_control_entries, :class => "ACM::Models::AccessControlEntries"

    include ACM::Models::Common

  end
end