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
        result = nil
        ActiveSupport::Notifications.instrument("groonga.search", sql: sql) do
          result = connection.select_value(sql)
        end
        result
      end

      def index_name
        "index_searcher_records_pgroonga"
      end

      def pgroonga_table_name
        @pgroonga_table_name ||= ActiveRecord::Base.connection.select_value("select pgroonga.table_name('#{index_name}')")
      end

      def filter_condition(user, project_ids, scope, attachments, open_issues)
        conditions = _filter_condition(user, project_ids, scope, attachments, open_issues)
        if conditions.empty?
          %Q[pgroonga_tuple_is_alive(ctid)]
        else
          %Q[pgroonga_tuple_is_alive(ctid) && #{build_condition('||', conditions)}]
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
