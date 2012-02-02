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

    one_to_one  :object, :key => :id, :class => "ACM::Models::Objects"
    one_to_many :members, :key => :group_id, :class => "ACM::Models::Members"
    one_to_many :access_control_entries, :key => :subject_id, :class => "ACM::Models::AccessControlEntries"

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
      @logger.debug("Group Id #{self.id}")

      output_group = {
        :id => self.immutable_id,
        :type => self.type,
        :additional_info => self.additional_info
      }

      if(self.type == :group.to_s)
        members = self.members
        output_members = []
        members.each { |member|
          @logger.debug("Member #{member.inspect} user #{member.user.inspect}")
          output_members.insert(0, member.user.immutable_id)
        }
        if(output_members.size() > 0)
          output_group[:members] = output_members
        end
      end

      output_group.update(
        :meta => {
          :created => self.created_at,
          :updated => self.last_updated_at,
          :schema => latest_schema
        }
      )

      @logger.debug("Group #{self.id} is #{output_group.inspect}")
      output_group.to_json()
    end

  end
end
