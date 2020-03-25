module FullTextSearch
  module SimilarSearcher
    module Model
      def self.included(base)
        base.include(InstanceMethods)
        base.class_eval do
          after_commit Callbacks
          after_destroy Callbacks
        end
        case ActiveRecord::Base.connection_config[:adapter]
        when "postgresql"
          require_dependency "full_text_search/similar_searcher/pgroonga"
          base.include(FullTextSearch::SimilarSearcher::PGroonga)
        when "mysql2"
          require_dependency "full_text_search/similar_searcher/mroonga"
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
          def after_commit(record)
            FullTextSearch::UpdateIssueContentJob
              .perform_later(record.class.name,
                             record.id,
                             "commit")
          end

          def after_destroy(record)
            # TODO: Refine
            case record
            when Issue
              FullTextSearch::UpdateIssueContentJob
                .perform_later(record.class.name,
                               record.id,
                               "destroy")
            when Journal
              FullTextSearch::UpdateIssueContentJob
                .perform_later(record.class.name,
                               record.id,
                               "destroy",
                               issue_id: record.journalized_id)
            end
          end
        end
      end
    end
  end
end
