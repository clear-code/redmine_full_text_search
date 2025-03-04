module FullTextSearch
  module Hooks
    module IssueQueryAnySearchable
      def sql_for_any_searchable_field(field, operator, value)
        # TODO: Implement AND searches across multiple fields.
        ## TODO List
        # - filter by open or closed issue
        # - filter by match leves('~', '*~')
        # - attached or not
        query = value.first
        filter_condition = build_filter_condition(User.current,
                                                  compute_target_project_ids)
        response = self.class.connection.select_value(
          build_any_searchable_query(query, filter_condition)
        )

        command = Groonga::Command.find("select").new("select", {})
        r = Groonga::Client::Response.parse(command, response)
        issue_ids = r.records.map { |row| row["issue_id"] }

        build_issue_id_condition(issue_ids, operator)
      end

      private

      def compute_target_project_ids
        if respond_to?(:project) && project
          [project.id]
        elsif has_filter?('project_id')
          case values_for('project_id').first
          when 'mine'
            User.current.projects.ids
          when 'bookmarks'
            User.current.bookmarked_project_ids
          else
            values_for('project_id')
          end
        else
          []
        end
      end

      def build_filter_condition(user, project_ids)
        target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
        target_ids &= project_ids if project_ids.present?
        if target_ids.present?
          "in_values(project_id, #{target_ids.join(',')})"
        else
          "1==1"
        end
      end

      def any_searchable_issues_index_name
        "index_issue_contents_pgroonga"
      end

      def build_any_searchable_query(query, condition_filter)
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
                      'filter', '#{condition_filter}'
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
