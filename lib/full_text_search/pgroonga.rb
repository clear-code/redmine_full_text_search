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
                      "#{sort_direction}_score,-original_updated_on,-original_created_on"
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
                   #{digest_columns.chomp}
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
        connection.select_value(sql)
      end

      def similar_issues(id:, limit: 5)
        issue = Issue.find(id)
        desc = issue.description
        # TODO
        sql = <<-SQL.strip_heredoc
        select pgroonga.command(
                 'select',
                 ARRAY[
                   'table', pgroonga.table_name('#{index_name}'),
                   'output_columns', 'issue_id, _score',
                   'filter', '(description *S ' || pgroonga.escape('#{desc}') || ' notes *S ' || pgroonga.escape('#{desc}') || ') && in_values(original_type, "Issue", "Journal") && (original_type == "Issue" && original_id != #{id})',
                   'drilldown', 'issue_id',
                   'limit', '#{limit}',
                   'sort_keys', '-_score'
                 ]
               )::json
        SQL
        response = connection.select_value(sql)
        command = Groonga::Command.find("select").new("select", {})
        r = Groonga::Client::Response.parse(command, response)
        if r.success?
          issue_ids = r.records.map do |row|
            row["issue_id"]
          end
          Issue.where(id: issue_ids).all
        else
          logger.warn(r.message)
          []
        end
      end

      def similar_issues2(id:, limit: 5)
        issue = Issue.find(id)
        desc = issue.description
        sql = <<-SQL.strip_heredoc
        select pgroonga.command(
                 'select',
                 ARRAY[
                   'table', pgroonga.table_name('#{similar_issues_index_name}'),
                   'output_columns', 'issue_id, _score',
                   'filter', '(contents *S ' || pgroonga.escape('#{desc}') || ') && issue_id != #{id}',
                   'limit', '#{limit}',
                   'sort_keys', '-_score'
                 ]
               )::json
        SQL
        response = connection.select_value(sql)
        command = Groonga::Command.find("select").new("select", {})
        r = Groonga::Client::Response.parse(command, response)
        if r.success?
          issue_ids = r.records.map do |row|
            row["issue_id"]
          end
          Issue.where(id: issue_ids).all
        else
          logger.warn(r.message)
          []
        end
      end

      def index_name
        "index_searcher_records_pgroonga"
      end

      def similar_issues_index_name
        "index_issue_contents_pgroonga"
      end

      def pgroonga_table_name
        @pgroonga_table_name ||= ActiveRecord::Base.connection.select_value("select pgroonga.table_name('#{index_name}')")
      end

      def filter_condition(user, project_ids, scope, attachments, open_issues)
        conditions = _filter_condition(user, project_ids, scope, attachments, open_issues)
        if conditions.empty?
          %Q[pgroonga_tuple_is_alive(ctid)]
        else
          %Q[pgroonga_tuple_is_alive(ctid) && (#{conditions.join(' || ')})]
        end
      end

      def title_digest(name, columns)
        <<-SQL.strip_heredoc
        'columns[#{name}].stage', 'output',
        'columns[#{name}].type', 'ShortText',
        'columns[#{name}].flags', 'COLUMN_SCALAR',
        'columns[#{name}].value', 'highlight_html(#{columns.join("+")})',
        SQL
      end

      def description_digest(name, columns)
        <<-SQL.strip_heredoc
        'columns[#{name}].stage', 'output',
        'columns[#{name}].type', 'ShortText',
        'columns[#{name}].flags', 'COLUMN_VECTOR',
        'columns[#{name}].value', 'snippet_html(#{columns.join("+")}) || vector_new()',
        SQL
      end
    end
  end
end
