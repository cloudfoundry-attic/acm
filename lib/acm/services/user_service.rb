require 'acm/services/acm_service'
require 'acm/models/subjects'

module ACM::Services

  class UserService < ACMService

    def create_user(opts = {})

      user = ACM::Models::Subjects.new(
        :immutable_id => !opts[:id].nil? ? opts[:id] : SecureRandom.uuid(),
        :type => :user.to_s,
        :additional_info => !opts[:additional_info].nil? ? opts[:additional_info] : nil
      )

      begin
        existing_user = ACM::Models::Subjects.filter(:immutable_id => user.immutable_id).first()
        if(existing_user.nil?)
          user.save
        else
          @logger.error("User id #{existing_user.immutable_id} already used")
          raise ACM::InvalidRequest.new("User id #{existing_user.immutable_id} already used")
        end
      rescue => e
        if e.kind_of?(ACM::ACMError)
          raise e
        else
          @logger.info("Failed to create a user #{e}")
          @logger.debug("Failed to create a user #{e.backtrace.inspect}")
          raise ACM::SystemInternalError.new()
        end
      end

      user.to_json()

    end

    def find_user(user_id)
      @logger.debug("find_user parameters #{user_id.inspect}")
      user = ACM::Models::Subjects.filter(:immutable_id => user_id, :type => :user.to_s).first()

      if(user.nil?)
        @logger.error("Could not find user with id #{user_id.inspect}")
        raise ACM::ObjectNotFound.new("#{user_id.inspect}")
      else
        @logger.debug("Found user #{user.inspect}")
      end

      user.to_json()
    end

    def get_user_info(user_id)
      @logger.debug("find_user parameters #{user_id.inspect}")
      user = ACM::Models::Subjects.filter(:immutable_id => user_id, :type => :user.to_s).first()

      if(user.nil?)
        @logger.error("Could not find user with id #{user_id.inspect}")
        raise ACM::ObjectNotFound.new("#{user_id.inspect}")
      else
        @logger.debug("Found user #{user.inspect}")
      end

      output = {:id => user[:immutable_id]}

      #Get the groups that the user belongs to
      groups = ACM::Models::Members.
                        join_table(:inner, :subjects, :id => :group_id).
                        filter(:user_id => user[:id]).distinct.select(:immutable_id).all()
      @logger.debug("Groups for user #{user.immutable_id} are #{groups.inspect}")

      if(!groups.nil? && groups.size > 0)
        output[:groups] = groups.map {|group| group[:immutable_id]}
      end

      @logger.debug("Output groups are #{output[:groups].inspect}")

      #Find the objects that reference the group
      group_objects = []
      if(!output[:groups].nil? && output[:groups].size() > 0)
        #find the aces for the group
        group_aces = ACM::Models::AccessControlEntries.
                      join_table(:inner, :ace_subject_map, :access_control_entry_id => :id).
                      join_table(:inner, :subjects, :id => :subject_id).
                      filter(:immutable_id => output[:groups]).select(:access_control_entries__object_id).all()

        if(!group_aces.nil? && group_aces.size > 0)
          group_aces = group_aces.map{|group_ace| group_ace[:object_id]}
        end

        @logger.debug("Aces for the group are #{group_aces.inspect}")
        group_aces.each { |ace_id|
          object_immutable_id = ACM::Models::Objects.filter(:id => ace_id).select(:immutable_id).first()
          if(!object_immutable_id.nil? && !group_objects.include?(object_immutable_id[:immutable_id]))
            group_objects.insert(0, object_immutable_id[:immutable_id])
          end
        }
      end

      @logger.debug("Group objects are #{group_objects.inspect}")

      #Find the objects that reference the user
      user_objects = []
      user_aces = user.access_control_entries
      user_aces = user_aces
      @logger.debug("Aces for the user are #{user_aces.inspect}")
      if(!user_aces.nil?)
        user_aces.each { |ace|
          object = ACM::Models::Objects.filter(:id => ace[:object_id]).select(:immutable_id).first()
          if(!object.nil? && !user_objects.include?(object[:immutable_id]))
            user_objects.insert(0, object[:immutable_id])
          end
        }
      end

      output_objects = []
      @logger.debug("User objects are #{user_objects.inspect}")
      output_objects = output_objects | user_objects
      @logger.debug("Group objects are #{group_objects.inspect}")
      output_objects = output_objects | group_objects

      if(output_objects.size() > 0)
        output[:objects] = output_objects
      end

      @logger.debug("Output is #{output.inspect}")
      output.to_json
    end

  end

end
