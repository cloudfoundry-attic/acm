require 'acm/models/objects'

Sham.define do
  name          { |index| "name-#{index}" }
  immutable_id  { SecureRandom.uuid }

end

module ACM::Models

  Objects.blueprint do
    name            { Sham.name }
    type            { "app_space" }
    immutable_id    { Sham.immutable_id }
    additional_info   { "{\"authentication_endpoint\":\"http://localhost:8080/cloudfoundry-identity-uaa\"}" }
  end

end
