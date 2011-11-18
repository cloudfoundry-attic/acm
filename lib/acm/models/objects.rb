require 'acm/models/acm_common_model'
require 'acm/models/permission_sets'
require 'acm/models/access_control_entries'

require 'sequel'
require 'json'

module ACM::Models
  class Objects < Sequel::Model(:objects)

    many_to_many :permission_sets,
                 :left_key => :object_id, :right_key => :permission_set_id,
                 :join_table => :object_permission_set_map,
                 :class => "ACM::Models::PermissionSets"

    one_to_many   :access_control_entries, :key => :object_id, :class => "ACM::Models::AccessControlEntries"

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
      output_object = {
        :name => self.name,
        :type => self.permission_sets.nil? || self.permission_sets.size == 0 ? nil : self.permission_sets[0].name,
        :id => self.immutable_id,
        :additional_info => self.additional_info,
        :meta => {
          :created => self.created_at,
          :updated => self.last_updated_at,
          :schema => latest_schema
        }
      }
      output_object[:acls] = {}
      access_control_entries.each { |access_control_entry|
        @logger.debug("Access control entry for object #{self.id} #{access_control_entry.inspect}")
        subject_array = []
        access_control_entry.subjects.each { |subject|
          subject_array.insert(0, subject.immutable_id)
        }
        @logger.debug("SubjectArray for acl id #{access_control_entry.id} is #{subject_array.inspect}")
        if(subject_array.size > 0)
          output_object[:acls][access_control_entry.permission.name] = subject_array
        end
      }

      @logger.debug("ACL hash for object #{self.id} is #{output_object[:acls].inspect}")

      output_object.to_json()
    end
  end
end
