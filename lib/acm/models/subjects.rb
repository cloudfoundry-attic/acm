require 'acm/models/acm_common_model'
require 'sequel'
require 'json'

module ACM::Models
  class Subjects < Sequel::Model(:subjects)
    plugin :validation_helpers

    def validate
      super
      validates_includes [:user.to_s, :group.to_s], :type, :message => 'is not valid'
    end

    one_to_one  :object, :class => "ACM::Models::Objects"
    many_to_one :members, :class => "ACM::Models::Members"

    include ACM::Models::Common

    def before_create
      super
      set_immutable_id
    end

    def set_immutable_id
      if(self.immutable_id.nil?)
        self.immutable_id = SecureRandom.uuid()
      end
      @logger.debug("Immutable id for subject #{self.type} is #{self.immutable_id}")
    end

    def to_json
      {
        :id => self.immutable_id,
        :type => self.type,
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