module FullTextSearch
  module Model
    def self.included(base)
      base.class_eval do
        after_save Callbacks
      end
    end

    class Callbacks
      # Copy data to searcher_records only for full text search.
      def self.after_save(record)
        searcher_record =
          FullTextSearch::SearcherRecord.find_or_create_by!(original_id: record.id,
                                                            original_type: record.class.name)
        case record
        when Project
          searcher_record.update_attributes!(name: record.name,
                                             description: record.description,
                                             identifier: record.identifier,
                                             status: record.status,
                                             created_on: record.created_on,
                                             updated_on: record.updated_on)
        when News
          searcher_record.update_attributes!(title: record.title,
                                             summary: record.summary,
                                             description: record.description,
                                             project_id: record.project_id,
                                             created_on: record.created_on)
        when Issue
          searcher_record.update_attributes!(project_id: record.tracker.project_id,
                                             tracker_id: record.tracker_id,
                                             subject: record.subject,
                                             description: record.subject,
                                             created_on: record.created_on,
                                             author_id: record.author_id,
                                             is_private: record.is_private,
                                             updated_on: record.updated_on)
        when Document
          searcher_record.update_attributes!(title: record.title,
                                             description: record.description,
                                             created_on: record.created_on)
        when Changeset
          searcher_record.update_attributes!(comments: record.comments,
                                             created_on: record.committed_on)
        when Message
          searcher_record.update_attributes!(subject: record.subject,
                                             content: record.content,
                                             created_on: record.created_on,
                                             updated_on: record.updated_on)
        when Journal
          # journal belongs to an issue for now.
          searcher_record.update_attributes!(project_id: record.issue.project_id,
                                             notes: record.notes,
                                             author_id: record.user_id,
                                             is_private: record.private_notes,
                                             created_on: record.created_on)
        when WikiPage
          searcher_record.update_attributes!(title: record.title,
                                             created_on: record.created_on)
        when WikiContent
          searcher_record.update_attributes!(text: record.text,
                                             updated_on: record.updated_on)
        when CustomValue
          searcher_record.update_attributes!(value: record.value)
        when Attachment
          searcher_record.update_attributes!(filename: record.filename,
                                             description: record.description,
                                             created_on: record.created_on)
        else
          # do nothing
        end
      end

      def self.after_destroy(record)
        FullTextSearch::SearcherRecord.where(original_id: record.original_id,
                                             original_type: record.original_type).destroy_all
      end
    end
  end
end
