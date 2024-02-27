module FullTextSearch
  class Tag < ApplicationRecord
    self.table_name = :fts_tags
    belongs_to :type, class_name: "FullTextSearch::TagType"

    if respond_to?(:connection_db_config)
      adapter = connection_db_config.adapter
    else
      adapter = connection_config[:adapter]
    end
    case adapter
    when "postgresql"
      include Pgroonga
    when "mysql2"
      include Mroonga
    end

    class << self
      def extension(ext)
        type = TagType.extension
        find_or_create_by(type_id: type.id,
                          name: ext.downcase)
      end

      def identifier(id)
        type = TagType.identifier
        find_or_create_by(type_id: type.id,
                          name: id)
      end

      def issue_status(issue_status_id)
        type = TagType.issue_status
        find_or_create_by(type_id: type.id,
                          name: issue_status_id.to_s)
      end

      def text_extraction(status)
        type = TagType.text_extraction
        find_or_create_by(type_id: type.id,
                          name: status)
      end

      def text_extraction_error
        text_extraction("error")
      end

      def text_extraction_yet
        text_extraction("yet")
      end

      def text_extraction_ids
        type = TagType.text_extraction
        where(type_id: type.id).select(:id).collect(&:id)
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
