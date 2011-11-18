require 'acm/services/acm_service'
require 'acm/models/objects'
require 'acm/models/permission_sets'

module ACM::Services

  class ObjectService < ACMService

    def create_object(opts = {})

      permission_sets = !opts[:permission_sets].nil? ? opts[:permission_sets] : nil
      name = !opts[:name].nil? ? opts[:name] : nil
      additional_info = !opts[:additional_info].nil? ? opts[:additional_info] : nil

      o = ACM::Models::Objects.new(
        :name => name,
        :additional_info => additional_info
      )

      ACM::Config.db.transaction do

        begin
          o.save

          #Get the requested permission sets and add them to the object
          if(!permission_sets.nil?)
            #Convert all the entries to strings (otherwise the query fails)
            permission_set_string_values = permission_sets.map do |permission_set_entry|
              permission_set_entry.to_s
            end
            @logger.debug("permission_set_string_values requested for object #{o.inspect} are #{permission_set_string_values.inspect}")

            @logger.debug("all permission sets #{ACM::Models::PermissionSets.all().inspect}")

            permission_set_entities = ACM::Models::PermissionSets.filter(:name => permission_set_string_values).all()
            @logger.debug("permission_set_entities are #{permission_set_entities.inspect}")

            permission_set_entities.each { |permission_set_entity|
              @logger.debug("permission set entity #{permission_set_entity.inspect}")
              o.add_permission_set(permission_set_entity)
            }

            @logger.debug("permission_set_string_values for object #{o.inspect} are #{permission_set_string_values.inspect}")

          end

        rescue => e
          @logger.info("Failed to create an object #{e}")
          @logger.debug("Failed to create an object #{e.backtrace.inspect}")
          raise ACM::SystemInternalError.new(e)
        end

      end

      o.to_json

    end

    def add_permission(obj_id, permission, user_id)

      object = ACM::Models::Objects.filter(:immutable_id => obj_id.to_s).first()

      requested_permission = ACM::Models::Permissions.join(:permission_sets, :id => :permission_set_id)
                                                    .join(:object_permission_set_map, :permission_set_id => :id)
                                                    .filter(:object_permission_set_map__object_id => object.id)
                                                    .filter(:permissions__name => permission.to_s).first()

      @logger.debug("requested permission #{requested_permission.inspect}")

      subject = ACM::Models::Subjects.filter(:immutable_id => user_id.to_s).first()

      new_access_control_entry = object.add_access_control_entry(:object => object, :permission_id => requested_permission.id, :subject_id => subject.id)

      @logger.debug("AccessControlEntry #{new_access_control_entry.inspect}")
      @logger.debug("Modified object #{object.inspect}")

      object.to_json
    end

  end

end
