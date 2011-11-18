require 'acm/services/acm_service'
require 'acm/models/subjects'

module ACM::Services

  class UserService < ACMService

    def create_user(opts = {})

      s = ACM::Models::Subjects.new(
        :immutable_id => !opts[:id].nil? ? opts[:id] : SecureRandom.uuid(),
        :type => :user.to_s,
        :additional_info => !opts[:additional_info].nil? ? opts[:additional_info] : nil
      )

      begin
        s.save
      rescue => e
        @logger.info("Failed to create a user #{e}")
        @logger.debug("Failed to create a user #{e.backtrace.inspect}")
        raise ACM::SystemInternalError.new()
      end

      s.to_json

    end

  end

end
