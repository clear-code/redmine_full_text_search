module FullTextSearch
  class Type < ApplicationRecord
    self.table_name = :fts_types

    class << self
      def [](key)
        case key
        when Class
          __send__(key.name.underscore)
        when ActiveRecord::Base
          __send__(key.class.name.underscore)
        when /\A[A-Z]/
          __send__(key.underscore)
        else
          __send__(key.singularize)
        end
      end

      def available?(name)
        respond_to?(name.singularize)
      end

      def attachment
        find_or_create_by(name: "Attachment")
      end

      def change
        find_or_create_by(name: "Change")
      end

      def changeset
        find_or_create_by(name: "Changeset")
      end

      def custom_value
        find_or_create_by(name: "CustomValue")
      end

      def document
        find_or_create_by(name: "Document")
      end

      def file
        find_or_create_by(name: "File")
      end

      def issue
        find_or_create_by(name: "Issue")
      end

      def journal
        find_or_create_by(name: "Journal")
      end

      def message
        find_or_create_by(name: "Message")
      end

      def news
        find_or_create_by(name: "News")
      end

      def project
        find_or_create_by(name: "Project")
      end

      def repository
        find_or_create_by(name: "Repository")
      end

      def version
        find_or_create_by(name: "Version")
      end

      def wiki_page
        find_or_create_by(name: "WikiPage")
      end
    end
  end
end
