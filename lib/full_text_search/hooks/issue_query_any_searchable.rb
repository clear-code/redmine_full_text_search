module FullTextSearch
  module Hooks
    module IssueQueryAnySearchable
      def sql_for_any_searchable_field(field, operator, value)
        return super(field, operator, value) unless operator.in?(["~", "*~", "!~"])

        raw_query = value.is_a?(Array) ? value.first.to_s : value.to_s
        # Extract tokens without using regex (split on whitespace)
        tokens = raw_query.split.map(&:strip).reject(&:empty?)
        return super(field, operator, value) if tokens.empty?

        project_scope = Project.allowed_to(:view_issues)
        if project
          projects = project_scope.where(project_statement)
        elsif has_filter?('project_id')
          case values_for('project_id').first
          when 'mine'
            project_ids = User.current.projects.ids
          when 'bookmarks'
            project_ids = User.current.bookmarked_project_ids
          else
            project_ids = values_for('project_id')
          end
          projects = project_scope.where(
            sql_for_field('project_id', operator_for('project_id'), project_ids, Project.table_name, 'id')
          )
        else
          projects = nil
        end

        is_open_issues = has_filter?('status_id') && operator_for('status_id') == 'o'
        issue_type_id = FullTextSearch::Type.issue.id

        # Determine target issue IDs for each token across issue, journals, attachments, custom values
        token_issue_id_sets = tokens.map do |token|
          target_scope = FullTextSearch::Target.all
          target_scope = target_scope.where(project_id: projects.map(&:id)) if projects.present?

          if Redmine::Database.postgresql?
            target_scope = target_scope.where(
              "fts_targets.title &@~ :q OR fts_targets.content &@~ :q",
              q: token
            )
          else
            target_scope = target_scope.where(
              "MATCH(fts_targets.title) AGAINST(:q IN BOOLEAN MODE) OR MATCH(fts_targets.content) AGAINST(:q IN BOOLEAN MODE)",
              q: token
            )
          end

          # Select matching container issue IDs (either issue itself or target attached to issue)
          issue_ids = target_scope.pluck(:source_id, :source_type_id, :container_id, :container_type_id).map do |src_id, src_type, cont_id, cont_type|
            if src_type == issue_type_id
              src_id
            elsif cont_type == issue_type_id
              cont_id
            else
              nil
            end
          end.compact.uniq

          issue_ids
        end

        # For operator '~' (AND), take the intersection across all tokens.
        # For '*~' (OR) or '!~' (NOT), take the union across all tokens.
        final_ids = if operator == "~"
          token_issue_id_sets.reduce(:&) || []
        else
          token_issue_id_sets.reduce(:|) || []
        end

        if is_open_issues && final_ids.present?
          final_ids = Issue.open.where(id: final_ids).pluck(:id)
        end

        # Filter visibility for current user
        if final_ids.present?
          final_ids = Issue.visible.where(id: final_ids).pluck(:id)
        end

        if final_ids.present?
          sw = (operator == '!~') ? 'NOT' : ''
          "#{Issue.table_name}.id #{sw} IN (#{final_ids.join(',')})"
        else
          operator == '!~' ? '1=1' : '1=0'
        end
      rescue => _e
        # Fall back gracefully to Redmine default implementation if any error occurs
        super(field, operator, value)
      end
    end
  end
end
