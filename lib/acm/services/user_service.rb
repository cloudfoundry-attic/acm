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

  end

end
