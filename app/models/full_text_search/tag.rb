module FullTextSearch
  class Tag < ActiveRecord::Base
    self.table_name = :fts_tags

    class << self
      def extension(ext)
        type = TagType.extension
        find_or_create_by(type_id: type.id,
                          name: ext.downcase)
      end

      def issue_status(issue_status_id)
        type = TagType.issue_status
        find_or_create_by(type_id: type.id,
                          name: issue_status_id.to_s)
      end

      def tracker(tracker_id)
        type = TagType.tracker
        find_or_create_by(type_id: type.id,
                          name: tracker_id.to_s)
      end

      def user(user_id)
        type = TagType.user
        find_or_create_by(type_id: type.id,
                          name: user_id.to_s)
      end
    end

    def value
      @value ||= compute_value
    end

    private
    def compute_value
      case type_id
      when TagType.issue_status.id
        IssueStatus.find(name.to_i)
      when TagType.tracker.id
        Tracker.find(name.to_i)
      when TagType.user.id
        User.find(name.to_i)
      else
        name
      end
    end
  end
end
