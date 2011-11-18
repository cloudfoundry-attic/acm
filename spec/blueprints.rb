require 'acm/models/objects'

Sham.define do
  name          { |index| "name-#{index}" }
  immutable_id  { SecureRandom.uuid }
  random_number { rand(1000) }

end

module ACM::Models

  PermissionSets.blueprint do
    id            { Sham.random_number }
    name          { "app_space_permission_set" }

  end

end
