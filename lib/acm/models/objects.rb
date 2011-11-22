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
      #Get the names out of the permission sets
      object_types = (self.permission_sets.nil? || self.permission_sets.size == 0) ?
                          nil :
                          self.permission_sets.map{|permission_set| permission_set.name}
      output_object = {
        :name => self.name,
        :permission_sets => object_types,
        :id => self.immutable_id,
        :additionalInfo => self.additional_info,
      }

      output_object[:acl] = {}
      access_control_entries.each { |access_control_entry|
        @logger.debug("Access Control entry #{access_control_entry.inspect}")
        perimission_name = access_control_entry.permission.name
        @logger.debug("Permission name #{perimission_name.inspect}")
        subjects = access_control_entry.subjects
        @logger.debug("Subjects #{subjects.inspect}")
        subject_list = []
        subjects.each{|subject| subject_list.insert(0, subject.immutable_id)}

        if(subject_list.size() > 0)
          output_object[:acl][perimission_name] = subject_list
        end
      }

      @logger.debug("ACL hash for object #{self.id} is #{output_object[:acl].inspect}")

      output_object.update(
        :meta => {
          :created => self.created_at,
          :updated => self.last_updated_at,
          :schema => latest_schema
        }
      )

      output_object.to_json()
    end
  end
end
