require 'acm/services/acm_service'
require 'acm/models/subjects'
require 'acm/models/members'

module ACM::Services

  class GroupService < ACMService

    def initialize
      super

      @user_service = ACM::Services::UserService.new()
    end

    def create_group(opts = {})

      group = ACM::Models::Subjects.new(
        :immutable_id => !opts[:id].nil? ? opts[:id] : SecureRandom.uuid(),
        :type => :group.to_s,
        :additional_info => !opts[:additional_info].nil? ? opts[:additional_info] : nil
      )

      ACM::Config.db.transaction do
        begin
          existing_group = ACM::Models::Subjects.filter(:immutable_id => group.immutable_id).first()
          if(existing_group.nil?)
            group.save
          else
            @logger.error("Group id #{existing_group.immutable_id} already used")
            raise ACM::InvalidRequest.new("Group id #{existing_group.immutable_id} already used")
          end

          if(!opts[:members].nil?)
            members = opts[:members]
            if(members.kind_of?(Array))
              members.each {|member|
                if(!member.nil?)
                  begin
                    user = ACM::Models::Subjects.filter(:immutable_id => member).first()
                    if(user.nil?)
                      @logger.debug("Could not find user #{member}. Creating the user")
                      user = ACM::Models::Subjects.new(:immutable_id => member, :type => :user.to_s)
                      user.save
                    end
                    group.add_member(:user_id => user.id)
                  end
                end
              }
            else
              @logger.error("Failed to create group. members must be an array")
              raise ACM::InvalidRequest.new("Failed to create group. members must be an array")
            end
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
      end

      group.to_json()
    end

    def find_group(group_id)
      @logger.debug("find_user parameters #{group_id.inspect}")
      group = ACM::Models::Subjects.filter(:immutable_id => group_id, :type => :group.to_s).first()

      if(group.nil?)
        @logger.error("Could not find user with id #{group_id.inspect}")
        raise ACM::ObjectNotFound.new("#{group_id.inspect}")
      else
        @logger.debug("Found user #{group.inspect}")
      end

      group.to_json()
    end

  end

end
