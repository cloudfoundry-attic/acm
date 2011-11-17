require 'acm/models/acm_common_model'
require 'acm/models/permission_set'

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
      self.immutable_id = SecureRandom.uuid()
      @logger.debug("Immutable id for object #{self.name} is #{self.immutable_id}")
    end

    def to_json
      {
        :name => self.name,
        :type => self.permission_sets.nil? || self.permission_sets.size == 0 ? nil : self.permission_sets[0].name,
        :id => self.immutable_id,
        :additional_info => self.additional_info,
        :meta => {
          :created => self.created_at,
          :updated => self.last_updated_at,
          :schema => latest_schema
        }
      }.to_json()
    end
  end
end
