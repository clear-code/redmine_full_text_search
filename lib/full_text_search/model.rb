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
        searcher_record = case record.class
                          when WikiContent
                            FullTextSearch::SearcherRecord.find_or_create_by!(
                              original_id: record.page_id,
                              original_type: "WikiPage"
                            )
                          else
                            FullTextSearch::SearcherRecord.find_or_create_by!(
                              original_id: record.id,
                              original_type: record.class.name
                            )
                          end
        case record
        when Project
          searcher_record.update_attributes!(project_id: record.id,
                                             name: record.name,
                                             description: record.description,
                                             identifier: record.identifier,
                                             status: record.status,
                                             created_on: record.created_on,
                                             updated_on: record.updated_on)
        when News
          searcher_record.update_attributes!(project_id: record.project_id,
                                             title: record.title,
                                             summary: record.summary,
                                             description: record.description,
                                             created_on: record.created_on)
        when Issue
          searcher_record.update_attributes!(project_id: record.project_id,
                                             tracker_id: record.tracker_id,
                                             subject: record.subject,
                                             description: record.subject,
                                             created_on: record.created_on,
                                             author_id: record.author_id,
                                             is_private: record.is_private,
                                             status_id: record.status_id,
                                             updated_on: record.updated_on)
        when Document
          searcher_record.update_attributes!(project_id: record.project_id,
                                             title: record.title,
                                             description: record.description,
                                             created_on: record.created_on)
        when Changeset
          searcher_record.update_attributes!(project_id: record.repository.project_id,
                                             comments: record.comments,
                                             created_on: record.committed_on)
        when Message
          searcher_record.update_attributes!(project_id: record.board.project_id,
                                             subject: record.subject,
                                             content: record.content,
                                             created_on: record.created_on,
                                             updated_on: record.updated_on)
        when Journal
          # journal belongs to an issue for now.
          searcher_record.update_attributes!(project_id: record.journalized.project_id,
                                             notes: record.notes,
                                             author_id: record.user_id,
                                             is_private: record.private_notes,
                                             created_on: record.created_on)
        when WikiPage
          searcher_record.update_attributes!(project_id: record.wiki.project_id,
                                             title: record.title,
                                             text: record.text,
                                             created_on: record.created_on,
                                             updated_on: record.updated_on)
        when WikiContent
          searcher_record.update_attributes!(project_id: record.page.wiki.project_id,
                                             text: recotd.text,
                                             updated_on: record.updated_on)
        when CustomValue
          # CustomValue belongs to issue for now.
          searcher_record.update_attributes!(project_id: record.customized.project_id,
                                             value: record.value)
        when Attachment
          case record.container_type
          when "Project"
            searcher_record.update_attributes!(project_id: record.container.id,
                                               container_id: record.container_id,
                                               container_type: record.container_type,
                                               filename: record.filename,
                                               description: record.description,
                                               created_on: record.created_on)
          else
            searcher_record.update_attributes!(project_id: record.container.project_id,
                                               container_id: record.container_id,
                                               container_type: record.container_type,
                                               filename: record.filename,
                                               description: record.description,
                                               created_on: record.created_on)
          end
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
