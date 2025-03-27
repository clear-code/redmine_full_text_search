module FullTextSearch
  module Hooks
    module IssueQueryAnySearchable
      include FullTextSearch::ConditionBuilder

      def sql_for_any_searchable_field(field, operator, value)
        query = value.first
        response = self.class.connection.select_value(
          build_any_searchable_query(query, build_filter_condition)
        )

        command = Groonga::Command.find("select").new("select", {})
        r = Groonga::Client::Response.parse(command, response)
        if r.success?
          issue_ids = r.records.map { |row| row["issue_id"] }
          build_issue_id_condition(issue_ids, operator)
        else
          if Rails.env.production?
            logger.warn(r.message)
            ''
          else
            raise r.message
          end
        end
      end

      private

      def compute_target_project_ids
        target_ids = Project.allowed_to(User.current, :view_issues).pluck(:id)
        compute_target_ids = if respond_to?(:project) && project
                               [project.id]
                             elsif has_filter?("project_id")
                               case values_for("project_id").first
                               when "mine"
                                 User.current.projects.ids
                               when "bookmarks"
                                 User.current.bookmarked_project_ids
                               else
                                 values_for("project_id")
                               end
                             else
                               []
                             end
        target_ids &= compute_target_ids if compute_target_ids.present?
        target_ids
      end

      def compute_target_issue_ids
        return unless has_filter?('status_id')
        staus_opened = operator_for('status_id') == 'o'
        Issue.visible.open(staus_opened).ids
      end

      def build_filter_condition
        conditions = []
        target_project_ids = compute_target_project_ids
        if target_project_ids.present?
          conditions << "in_values(project_id, #{target_project_ids.join(",")})"
        end
        target_issue_ids = compute_target_issue_ids
        if target_issue_ids.present?
          conditions << "in_values(issue_id, #{target_issue_ids.join(",")})"
        end
        conditions << "1==1" if conditions.empty?
        build_condition("&&", conditions)
      end

      def any_searchable_issues_index_name
        "index_issue_contents_pgroonga"
      end

      def build_any_searchable_query(query, filter_condition)
        sql = case ActiveRecord::Base.connection_db_config.adapter
              when "postgresql"
                <<-SQL.strip_heredoc
                  SELECT pgroonga_command(
                    'select',
                    ARRAY[
                      'table', pgroonga_table_name('#{any_searchable_issues_index_name}'),
                      'match_columns', 'content',
                      'output_columns', 'issue_id',
                      'query', pgroonga_query_escape(:query),
                      'filter', '#{filter_condition}'
                    ]
                  )::json
                SQL
              when "mysql2"
                # TODO: build query using Mroonga.
              end
        ActiveRecord::Base.send(:sanitize_sql_array, [sql, query: query])
      end

      def build_issue_id_condition(issue_ids, operator)
        return operator == '!~' ? '1=1' : '1=0' if issue_ids.empty?

        if operator == '!~'
          "#{Issue.table_name}.id NOT IN (#{issue_ids.join(',')})"
        else
          "#{Issue.table_name}.id IN (#{issue_ids.join(',')})"
        end
      end
    end
  end
end
