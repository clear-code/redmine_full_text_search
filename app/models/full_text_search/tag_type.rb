module FullTextSearch
  class TagType < ActiveRecord::Base
    self.table_name = :fts_tag_types

    class << self
      def extension
        find_or_create_by(name: "extension")
      end

      def identifier
        find_or_create_by(name: "identifier")
      end

      def issue_status
        find_or_create_by(name: "issue-status")
      end

      def text_extraction
        find_or_create_by(name: "text-extraction")
      end

      def tracker
        find_or_create_by(name: "tracker")
      end

      def user
        find_or_create_by(name: "user")
      end
    end
  end
end
