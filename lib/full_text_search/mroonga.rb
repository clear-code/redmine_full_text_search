module FullTextSearch
  module Mroonga
    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
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
                  "mroonga_escape('#{query}')"
                else
                  "\'#{query}\'"
                end
        sql = <<-SQL.strip_heredoc
        select mroonga_command(
                 'select',
                 'table', 'searcher_records',
                 'output_columns', '*,_score',
                 #{digest_columns.chomp}
                 'drilldown', 'original_type',
                 'match_columns', '#{target_columns(titles_only).join('||')}',
                 'query', #{query},
                 'filter', '#{filter_condition(user, project_ids, scope, attachments, open_issues)}',
                 'limit', '#{limit}',
                 'offset', '#{offset}',
                 'sort_keys', '#{sort_keys}'
               )
        SQL
        r = nil
        ActiveSupport::Notifications.instrument("groonga.search", sql: sql) do
          r = connection.select_value(sql)
        end
        # NOTE: Hack to use Groonga::Client::Response.parse
        # Raise Mysql2::Error if error occurred
        body = JSON.parse(r)
        header = [0, 0, 0]
        [header, body].to_json
      end

      def filter_condition(user, project_ids, scope, attachments, open_issues)
        conditions = _filter_condition(user, project_ids, scope, attachments, open_issues)
        if conditions.empty?
          "1==1"
        else
          build_condition("||", conditions)
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
