require 'sequel'

module ACM::Models
  class AceSubjectMap < Sequel::Model(:ace_subject_map)

    many_to_one :ace, :class => "ACM::Models::AccessControlEntries"
    many_to_one :subject, :class => "ACM::Models::Subjects"

  end
end
