module FullTextSearch
  module SimilarSearcher
    module Model
      def self.included(base)
        base.include(InstanceMethods)
        if base.respond_to?(:connection_db_config)
          adapter = base.connection_db_config.adapter
        else
          adapter = base.connection_config[:adapter]
        end
        case adapter
        when "postgresql"
          base.include(FullTextSearch::SimilarSearcher::Pgroonga)
        when "mysql2"
          base.include(FullTextSearch::SimilarSearcher::Mroonga)
        end
      end

      module InstanceMethods
        def filter_condition(user = User.current, project_ids = [])
          conditions = []
          target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
          target_ids &= project_ids if project_ids.present?
          if target_ids.present?
            conditions << ("in_values(project_id, #{target_ids.join(',')})")
          end
          if conditions.empty?
            "1==1"
          else
            build_condition("||", conditions)
          end
        end

        def similar_content
          contents = [subject, description]
          notes = journals.sort_by(&:id).map(&:notes)
          contents.concat(notes)
          attachments.order(:id).each do |attachment|
            contents << attachment.filename if attachment.filename.present?
            contents << attachment.description if attachment.description.present?
          end
          contents.join("\n")
        end
      end
    end
  end
end
