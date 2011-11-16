require 'acm/models/acm_common_model'

require 'sequel'
require 'json'

module ACM::Models
  class Objects < Sequel::Model(:objects)

    many_to_many :permission_sets,
                 :left_key => :object_id, :right_key => :permission_set_id,
                 :join_table => :object_permission_set_map

    include ACM::Models::Common

    def before_create
      super
      set_immutable_id

    end

    def set_immutable_id
      self.immutable_id = SecureRandom.uuid
      @logger.debug("Immutable id for object #{self.name} is #{self.immutable_id}")
    end

    def to_json
      {
        "name" => self.name
      }.to_json()
    end
  end
end
