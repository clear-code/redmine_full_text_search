module FullTextSearch
  module Model
    def self.included(base)
      base.class_eval do
        after_save Callbacks
        after_destroy Callbacks
      end
    end

    class Callbacks
      # Copy data to searcher_records only for full text search.
      def self.after_save(record)
        searcher_record =
          case record
          when WikiContent
            FullTextSearch::SearcherRecord.find_or_initialize_by(
              original_id: record.page_id,
              original_type: "WikiPage"
            )
          else
            FullTextSearch::SearcherRecord.find_or_initialize_by(
              original_id: record.id,
              original_type: record.class.name
            )
          end
        Rails.logger.debug(searcher_record: searcher_record)
        case record
        when Project
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.project_id = record.id
          searcher_record.project_name = record.name
          searcher_record.name = record.name
          searcher_record.description = record.description
          searcher_record.identifier = record.identifier
          searcher_record.status = record.status
          searcher_record.original_created_on = record.created_on
          searcher_record.original_updated_on = record.updated_on
          searcher_record.save!
        when News
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.project_id = record.project_id
          searcher_record.project_name = record.project.name
          searcher_record.title = record.title
          searcher_record.summary = record.summary
          searcher_record.description = record.description
          searcher_record.original_created_on = record.created_on
          searcher_record.save!
        when Issue
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.project_id = record.project_id
          searcher_record.project_name = record.project.name
          searcher_record.tracker_id = record.tracker_id
          searcher_record.issue_id = record.id
          searcher_record.subject = record.subject
          searcher_record.description = record.description
          searcher_record.author_id = record.author_id
          searcher_record.is_private = record.is_private
          searcher_record.status_id = record.status_id
          searcher_record.original_created_on = record.created_on
          searcher_record.original_updated_on = record.updated_on
          searcher_record.save!
        when Document
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.project_id = record.project_id
          searcher_record.project_name = record.project.name
          searcher_record.title = record.title
          searcher_record.description = record.description
          searcher_record.original_created_on = record.created_on
          searcher_record.save!
        when Changeset
          short_comments, long_comments = record.comments.split(/(?:\r?\n)+/, 2).map(&:strip)
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.project_id = record.repository.project_id
          searcher_record.project_name = record.repository.project.name
          searcher_record.comments = record.comments
          searcher_record.short_comments = short_comments
          searcher_record.long_comments = long_comments
          searcher_record.original_created_on = record.committed_on
          searcher_record.save!
        when Message
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.project_id = record.board.project_id
          searcher_record.project_name = record.board.project.name
          searcher_record.subject = record.subject
          searcher_record.content = record.content
          searcher_record.original_created_on = record.created_on
          searcher_record.original_updated_on = record.updated_on
          searcher_record.save!
        when Journal
          # journal belongs to an issue for now.
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.project_id = record.journalized.project_id
          searcher_record.project_name = record.journalized.project.name
          searcher_record.issue_id = record.journalized_id
          searcher_record.notes = record.notes
          searcher_record.author_id = record.user_id
          searcher_record.private_notes = record.private_notes
          searcher_record.status_id = record.journalized.status_id
          searcher_record.original_created_on = record.created_on
          searcher_record.save!
        when WikiPage
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.project_id = record.wiki.project_id
          searcher_record.project_name = record.wiki.project.name
          searcher_record.title = record.title
          searcher_record.text = record.text
          searcher_record.original_created_on = record.created_on
          searcher_record.original_updated_on = record.updated_on
          searcher_record.save!
        when WikiContent
          searcher_record.original_id = record.page_id
          searcher_record.original_type = "WikiPage"
          searcher_record.project_id = record.page.wiki.project_id
          searcher_record.project_name = record.page.wiki.project.name
          searcher_record.text = record.text
          searcher_record.original_updated_on = record.updated_on
          searcher_record.save!
        when CustomValue
          return unless record.custom_field.searchable
          # searchable CustomValue belongs to issue or project
          searcher_record.original_id = record.id
          searcher_record.original_type = record.class.name
          searcher_record.value = record.value
          searcher_record.custom_field_id = record.custom_field_id
          case record.customized_type
          when "Project"
            searcher_record.project_id = record.customized.id
            searcher_record.project_name = record.customized.name
          when "Issue"
            searcher_record.project_id = record.customized.project_id
            searcher_record.project_name = record.customized.project.name
            searcher_record.status_id = record.customized.status_id
            searcher_record.is_private = record.customized.is_private
          else
            # Not in use for now...
            searcher_record.project_id = record.customized.project_id
            searcher_record.project_name = record.customized.project.name
          end
          searcher_record.save!
        when Attachment
          # container is not specified when initial upload
          return if record.container_type.nil?
          searcher_record.original_id = record.id
          searcher_record.original_type = "Attachment"
          searcher_record.container_id = record.container_id
          searcher_record.container_type = record.container_type
          searcher_record.filename = record.filename
          searcher_record.description = record.description
          searcher_record.original_created_on = record.created_on
          case record.container_type
          when "Project"
            searcher_record.project_id = record.container.id
            searcher_record.project_name = record.container.name
          when "Message"
            searcher_record.project_id = record.container.board.project_id
            searcher_record.project_name = record.container.board.project.name
          when "WikiPage"
            wiki_page = record.container
            searcher_record.project_id = wiki_page.wiki.project_id
            searcher_record.project_name = wiki_page.wiki.project.name
          when "Issue"
            searcher_record.project_id = record.container.project_id
            searcher_record.project_name = record.container.project.name
            searcher_record.status_id = record.container.status_id
            searcher_record.is_private = record.container.is_private
          else
            searcher_record.project_id = record.container.project_id
            searcher_record.project_name = record.container.project.name
          end
          searcher_record.save!
        else
          # do nothing
        end
      end

      def self.after_destroy(record)
        FullTextSearch::SearcherRecord.where(original_id: record.id,
                                             original_type: record.class.name).destroy_all
      end
    end
  end
end
