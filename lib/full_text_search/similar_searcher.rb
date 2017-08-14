module FullTextSearch
  module SimilarSearcher
    module Model
      def self.included(base)
        base.class_eval do
          after_save Callbacks
          after_destroy Callbacks
        end
        case
        when Redmine::Database.postgresql?
          require "full_text_search/similar_searcher/pgroonga"
          base.include(FullTextSearch::SimilarSearcher::PGroonga)
        when Redmine::Database.mysql?
          require "full_text_search/similar_searcher/mroonga"
          base.include(FullTextSearch::SimilarSearcher::Mroonga)
        end
      end

      # Add callbacks to Issue
      class Callbacks
        class << self
          def after_save(record)
            case record
            when Issue
              issue_id = record.id
              FullTextSearch::IssueContent
                .where(issue_id: issue_id)
                .update(subject: record.subject,
                        contents: create_contents(issue_id))
            when Journal
              issue_id = record.journalized_id
              FullTextSearch::IssueContent
                .where(issue_id: issue_id)
                .update(contents: create_contents(issue_id))
            end
          end

          def after_destroy(record)
            case record
            when Issue
              FullTextSearch::IssueContent.where(issue_id: record.id).destroy_all
            when Journal
              issue_id = record.journalized_id
              FullTextSearch::IssueContent
                .where(issue_id: issue_id)
                .update(contents: create_contents(issue_id))
            end
          end

          def create_contents(issue_id)
            issue = Issue.eager_load(:journals).find(issue_id)
            contents = [issue.subject, issue.description] + issue.journals.sort_by(&:id).map(&:notes)
            contents.join("\n")
          end
        end
      end
    end
  end
end
