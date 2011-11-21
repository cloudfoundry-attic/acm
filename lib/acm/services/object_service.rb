require 'acm/services/acm_service'
require 'acm/models/objects'
require 'acm/models/permission_sets'
require 'acm/models/ace_subject_map'

module ACM::Services

  class ObjectService < ACMService

    def create_object(opts = {})
      @logger.debug("create object parameters #{opts}")

      permission_sets = get_option(opts, :permission_sets)
      name = get_option(opts, :name)
      additional_info = get_option(opts, :additional_info)
      acls = get_option(opts, :acls)

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

            @logger.debug("permission_set_string_values for object #{o.id} are #{permission_set_string_values.inspect}")

          end

          @logger.debug("Acls requested are #{acls.inspect}")
          if(!acls.nil?)
            #ACLs are a list of hashes
            acls.each { |permission, user_id_set|
              user_id_set.each { |user_id|
                begin
                  add_permission(o.immutable_id, permission, user_id)
                rescue => e
                  @logger.error("Failed to add permission #{permission.inspect} on object #{o.immutable_id} for user #{user_id}")
                  raise ACM::InvalidRequest.new("Failed to add permission #{permission} on object #{o.immutable_id} for user #{user_id}")
                end
              }
            }

          end

        rescue => e
          @logger.error("Failed to create an object #{e}")
          @logger.debug("Failed to create an object #{e.backtrace.inspect}")
          if (e.kind_of?(ACM::ACMError))
            raise e
          else
            raise ACM::SystemInternalError.new(e)
          end
        end

      end

      @logger.debug("Object created is #{o.inspect}")

      o.to_json
    end

    def get_option(map, key)
      map[key].nil? ? nil : map[key]
    end

    def read_object(obj_id)

      object = ACM::Models::Objects.filter(:immutable_id => obj_id).first()

      if(object.nil?)
        @logger.error("Could not find object with id #{obj_id.inspect}")
        raise ACM::ObjectNotFound.new("#{obj_id.inspect}")
      end

      object.to_json()
    end

    def add_permission(obj_id, permission, user_id)
      @logger.debug("adding permission #{permission} on object #{obj_id} and user #{user_id}")

      #Find the object
      object = ACM::Models::Objects.filter(:immutable_id => obj_id.to_s).first()
      @logger.debug("requested object #{object.inspect}")

      #Find the requested permission only if it belongs to a permission set that is related to that object
      requested_permission = ACM::Models::Permissions.join(:permission_sets, :id => :permission_set_id)
                                                    .join(:object_permission_set_map, :permission_set_id => :id)
                                                    .filter(:object_permission_set_map__object_id => object.id)
                                                    .filter(:permissions__name => permission.to_s)
                                                    .select(:permissions__id, :permissions__name)
                                                    .first()
      @logger.debug("requested permission #{requested_permission.inspect}")

      #find the subject
      subject = ACM::Models::Subjects.filter(:immutable_id => user_id.to_s).first()
      @logger.debug("requested subject #{requested_permission.inspect}")

      ACM::Config.db.transaction do
        object_aces = object.access_control_entries.select{|ace| ace.permission_id == requested_permission.id}
        ace = nil
        if(object_aces.size() == 0)
          ace = object.add_access_control_entry(:object_id => object.id,
                                               :permission_id => requested_permission.id)
          @logger.debug("new ace #{ace.inspect}")
        else
          ace = object_aces[0]
          @logger.debug("found ace #{ace.inspect}")
        end

        ace.add_subject(subject)

        @logger.debug("subjects for ace #{ace.id} are #{ACM::Models::AceSubjectMap.filter(:access_control_entry_id => ace.id).count().inspect}")
      end

      object.to_json
    end

  end

end
