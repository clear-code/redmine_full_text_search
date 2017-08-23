module FullTextSearch
  module SimilarSearcher
    module Model
      def self.included(base)
        base.include(InstanceMethods)
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

      module InstanceMethods
        def filter_condition(user = User.current, project_ids = [])
          conditions = []
          target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
          target_ids &= project_ids if project_ids.present?
          if target_ids.present?
            # TODO: support private issue
            conditions << build_condition("&&",
                                          "is_private == false",
                                          "in_values(project_id, #{target_ids.join(',')})")
          end
          if conditions.empty?
            "1==1"
          else
            build_condition("||", conditions)
          end
        end
      end

      # Add callbacks to Issue
      class Callbacks
        class << self
          def after_save(record)
            case record
            when Issue
              r = FullTextSearch::IssueContent.find_or_initialize_by(issue_id: record.id)
              r.project_id = record.project_id
              r.subject = record.subject
              r.contents = create_contents(record.id)
              r.status_id = record.status_id
              r.is_private = record.is_private
              r.save
            when Journal
              issue_id = record.journalized_id
              FullTextSearch::IssueContent
                .where(issue_id: issue_id)
                .update_all(contents: create_contents(issue_id))
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
                .update_all(contents: create_contents(issue_id, excludes: [record.id]))
            end
          end

          def create_contents(issue_id, excludes: [])
            issue = Issue.eager_load(:journals).find(issue_id)
            contents = [issue.subject, issue.description]
            notes = issue.journals
              .reject {|j| j.notes.blank? || excludes.include?(j.id) }
              .sort_by(&:id)
              .map(&:notes)
            contents.concat(notes)
            contents.join("\n")
          end
        end
      end
    end
  end
end
