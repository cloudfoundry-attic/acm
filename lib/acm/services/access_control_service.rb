require 'acm/services/acm_service'
require 'acm/models/subjects'
require 'acm/models/members'
require 'acm/models/objects'
require 'acm/models/permissions'

module ACM::Services

  class AccessControlService < ACMService

    def check_access(object_id, subject_id, permissions)

      if(subject_id.nil?)
        @logger.debug("Subject is nil")
        raise ACM::ObjectNotFound.new("")
      end

      if(permissions.nil? || permissions.size() == 0)
        @logger.debug("No permissions")
        raise ACM::ObjectNotFound.new("")
      end

      object = ACM::Models::Objects.filter(:immutable_id => object_id).first()

      if(object.nil?)
        @logger.debug("Could not find the object #{object_id}")
        raise ACM::ObjectNotFound.new("")
      end

      permission_ids = ACM::Models::Permissions.filter(:name => permissions).all().map{|p| p.id}
      if(permission_ids.nil? || permission_ids.size() == 0 || permission_ids.size() != permissions.size())
        @logger.debug("Permissions did not match")
        raise ACM::ObjectNotFound.new("")
      end

      acl = ACM::Models::AccessControlEntries.filter(:object_id => object.id,
                                                      :permission_id => permission_ids).
                                                      all()
      if(acl.nil? || acl.size() == 0)
        @logger.debug("ACL did not match")
        raise ACM::ObjectNotFound.new("")
      end

      subjects = []
      acl.each { |ace|
        subjects = ace.subjects.map{|subject|
          if(subject.type == :user.to_s)
            subject.immutable_id
          else
            group_id = subject.immutable_id
            members = ACM::Models::Members.filter(:group_id => group_id).all().map { |member|
              member.user.immutable_id
            }
          end
        }
        if(subjects.nil? || subjects.size() == 0)
          @logger.debug("No subjects for acl #{acl.inspect}")
          raise ACM::ObjectNotFound.new("")
        end

        @logger.debug("Ace #{ace.inspect} Subjects #{subjects.inspect}. Searching for #{subject_id}")
        if(subjects.index(subject_id.to_s).nil?)
          @logger.debug("No matching subjects for acl #{acl.inspect}")
          raise ACM::ObjectNotFound.new("")
        end
      }

      @logger.info("Access OK")
    end

  end
end