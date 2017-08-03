module FullTextSearch
  module PGroonga
    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      #
      #
      # @params order_target "score" or "date"
      # @params order_type   "desc" or "asc"
      def search(query,
                 user: User.current,
                 project_ids: [],
                 scope: [],
                 attachments: "0",
                 all_words: true,
                 titles_only: false,
                 open_issues: false,
                 offset: nil,
                 limit: 10,
                 order_target: "score",
                 order_type: "desc",
                 query_escape: false)
        sort_direction = order_type == "desc" ? "-" : ""
        sort_keys = case order_target
                    when "score"
                      "#{sort_direction}_score"
                    when "date"
                      "#{sort_direction}original_updated_on, #{sort_direction}original_created_on"
                    end
        query = if query_escape
                  "pgroonga.query_escape('#{query}')"
                else
                  "'#{query}'"
                end
        sql = <<-SQL.strip_heredoc
        select pgroonga.command(
                 'select',
                 ARRAY[
                   'table', pgroonga.table_name('#{index_name}'),
                   'output_columns', '*,_score',
                   #{snippet_columns.chomp}
                   'drilldown', 'original_type',
                   'match_columns', '#{target_columns(titles_only).join("||")}',
                   'query', #{query},
                   'filter', '#{filter_condition(user, project_ids, scope, attachments, open_issues)}',
                   'limit', '#{limit}',
                   'offset', '#{offset}',
                   'sort_keys', '#{sort_keys}'
                 ]
               )::json
        SQL
        logger.debug(sql)
        connection.select_value(sql)
      end

      def index_name
        "index_searcher_records_pgroonga"
      end

      def pgroonga_table_name
        @pgroonga_table_name ||= ActiveRecord::Base.connection.select_value("select pgroonga.table_name('#{index_name}')")
      end

      def snippet_columns
        snippet_column("title", %w(subject title filename name)) +
          snippet_column("description", %w(content text notes description summary value))
      end

      def snippet_column(name, columns)
        <<-SQL.strip_heredoc
        'columns[#{name}_snippet].stage', 'output',
        'columns[#{name}_snippet].type', 'ShortText',
        'columns[#{name}_snippet].flags', 'COLUMN_VECTOR',
        'columns[#{name}_snippet].value', 'snippet_html(#{columns.join("+")}) || vector_new()',
        SQL
      end

      # scope # => [:issues, :news, :documents, :changesets, :wiki_pages, :messages, :projects]
      def filter_condition(user, project_ids, scope, attachments, open_issues)
        conditions = []
        unless attachments == "only"
          scope.each do |s|
            case s
            when "projects"
              if project_ids.empty?
                project_ids = if user.respond_to?(:visible_project_ids)
                                user.visible_project_ids
                              else
                                Project.visible(user).pluck(:id)
                              end
              end
              if project_ids.present?
                conditions << build_condition('original_type == "Project"',
                                              "in_values(original_id, #{project_ids.join(',')})")
              end
              target_ids = CustomField.visible(user).pluck(:id)
              if target_ids.present?
                conditions << build_condition('original_type == "CustomValue"',
                                              "in_values(custom_field_id, #{target_ids.join(',')})")
              end
            when "issues"
              # TODO: Support private issue
              target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition('original_type == "Issue"',
                                              "is_private == false",
                                              "in_values(project_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
              # visible_project_ids[:issue_private] = Project.allowed_to(user, :view_private_issue)
              target_ids = Project.allowed_to(user, :view_notes).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition('original_type == "Journal"',
                                              "private_notes == false",
                                              "in_values(project_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
              target_ids = Project.allowed_to(user, :view_private_notes).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition('original_type == "Journal"',
                                              "private_notes == true",
                                              "in_values(project_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
              target_ids = CustomField.visible(user).pluck(:id)
              if target_ids.present?
                conditions << build_condition('original_type == "CustomValue"',
                                              "is_private == false",
                                              "in_values(custom_field_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
            when "wiki_pages"
              target_ids = Project.allowed_to(user, :view_wiki_pages).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition('in_values(original_type, "WikiPage", "WikiContent")',
                                              "in_values(project_id, #{target_ids.join(',')})")
              end
            else
              target_ids = Project.allowed_to(user, :"view_#{s}").pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition(%Q[original_type == "#{s.classify}"],
                                              "in_values(project_id, #{target_ids.join(',')})")
              end
            end
          end
        end
        conditions.concat(attachments_conditions(user, project_ids, scope, attachments, open_issues))
        if conditions.empty?
          %Q[pgroonga_tuple_is_alive(ctid)]
        else
          %Q[pgroonga_tuple_is_alive(ctid) && (#{conditions.join(' || ')})]
        end
      end

      # TODO Attachmentはコンテナごとに条件が必要。コンテナを見ることができたら検索可能にする
      # container_type: Issue, Journal, File, Document, News, WikiPage, Version, Message
      def attachments_conditions(user, project_ids, scope, attachments, open_issues)
        conditions = []
        case attachments
        when "0"
          # do not search attachments
        when "1", "only"
          # search attachments
          scope.each do |s|
            case s
            when "issues"
              # TODO: Support private issue?
              target_ids = Project.allowed_to(user, :view_issues).pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition('original_type == "Attachment"',
                                              'container_type == "Issue"',
                                              "is_private == false",
                                              "in_values(project_id, #{target_ids.join(',')})",
                                              open_issues_condition(open_issues))
              end
            when "projects", "documents", "news", "wiki_pages", "messages", "versions"
              target_ids = Project.allowed_to(user, :"view_#{s}").pluck(:id)
              target_ids &= project_ids if project_ids.present?
              if target_ids.present?
                conditions << build_condition('original_type == "Attachment"',
                                              %Q[container_type == "#{s.classify}"],
                                              "in_values(project_id, #{target_ids.join(',')})")
              end
            end
          end
        end
        conditions
      end

      def build_condition(*args)
        "(#{args.compact.join(' && ')})"
      end

      def open_issues_condition(open_issues)
        return nil unless open_issues
        @status_ids ||= IssueStatus.where(is_closed: false).pluck(:id)
        "in_values(status_id, #{@status_ids.join(',')})"
      end
    end
  end
end
