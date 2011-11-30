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
      else
        if(!permissions.kind_of?(Array)) #The code below only works with arrays
          permissions = [permissions]
        end
      end

      #Find the object
      object = ACM::Models::Objects.filter(:immutable_id => object_id).first()

      if(object.nil?)
        @logger.debug("Could not find the object #{object_id}")
        raise ACM::ObjectNotFound.new("")
      end

      #Find the permission entities that need to be checked
      permission_ids = ACM::Models::Permissions.filter(:name => permissions).all().map{|p| p.id}
      #All the permissions must exist. That's why the size of the input must match the size of the permissions query
      if(permission_ids.nil? || permission_ids.size() == 0 || permission_ids.size() < permissions.size())
        @logger.debug("Permissions did not match #{permission_ids.inspect} #{permissions.inspect} #{permission_ids.size()} #{permissions.size()}")
        raise ACM::ObjectNotFound.new("")
      end

      #Find the aces for the object and set of permissions
      acl = ACM::Models::AccessControlEntries.filter(:object_id => object.id,
                                                      :permission_id => permission_ids).
                                                      all()
      if(acl.nil? || acl.size() == 0)
        @logger.debug("ACL did not match")
        raise ACM::ObjectNotFound.new("")
      end

      acl.each { |ace| #Go through each ace
        found = false

        ace.subjects.each{|subject| #Search the subjects for each ace

          if(subject.type == :user.to_s)
            #If the subject has not already been found and we have a match, return a true
            found = (found == false && subject.immutable_id.eql?(subject_id.to_s)) ? true : false
          else                              #If the subject is a group, find the members
            group_id = subject.immutable_id
            found = (found == false && group_id.eql?(subject_id.to_s)) ? true : false

            #If the group was not the subject being searched for, search the members
            if(!found)
              ACM::Models::Members.filter(:group_id => subject.id).all().each { |member|
                found = (found == false && member.user.immutable_id.eql?(subject_id.to_s)) ? true : false
                if(found)
                  break
                end
              }
            end
          end

          #Don't go any further in this search if the subject has already been found
          if(found)
            break
          end
        }

        @logger.debug("Ace #{ace.inspect} Searching for #{subject_id}")
        if(!found)  #If an ace does not contain the subject, the operation fails
          @logger.debug("No matching subjects for acl #{acl.inspect}")
          raise ACM::ObjectNotFound.new("")
        end
      }
      #Every ace contained that subject

      @logger.info("Access OK")
    end

  end
end