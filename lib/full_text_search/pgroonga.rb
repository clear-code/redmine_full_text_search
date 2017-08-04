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
        connection.select_value(sql)
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
          %Q[pgroonga_tuple_is_alive(ctid) && (#{conditions.join(' || ')})]
        end
      end

      def snippet_column(name, columns)
        <<-SQL.strip_heredoc
        'columns[#{name}_snippet].stage', 'output',
        'columns[#{name}_snippet].type', 'ShortText',
        'columns[#{name}_snippet].flags', 'COLUMN_VECTOR',
        'columns[#{name}_snippet].value', 'snippet_html(#{columns.join("+")}) || vector_new()',
        SQL
      end
    end
  end
end
