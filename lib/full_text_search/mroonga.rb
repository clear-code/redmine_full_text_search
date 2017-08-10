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
        # mroonga_command cannot contain new line
        # mroonga_command can accept multiple arguments since 7.0.5
        if mroonga_version >= "7.05"
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
        else
          query = if query_escape
                    "\\'" + connection.select_value("select mroonga_escape('#{query}')") + "\\'"
                  else
                    "\\'#{query}\\'"
                  end
          sql = [
            "select mroonga_command('",
            "select --table searcher_records",
            "--output_columns *,_score",
            digest_columns,
            "--drilldown original_type",
            "--match_columns #{target_columns(titles_only).join('||')}",
            "--query #{query}",
            "--filter \\'#{filter_condition(user, project_ids, scope, attachments, open_issues)}\\'",
            "--limit #{limit}",
            "--offset #{offset}",
            "--sort_keys \\'#{sort_keys}\\'",
            "'",
            ")"
          ].flatten.join(" ")
        end
        r = connection.select_value(sql)
        # NOTE: Hack to use Groonga::Client::Response.parse
        # Raise Mysql2::Error if error occurred
        body = JSON.parse(r)
        header = [0, 0, 0]
        [header, body].to_json
      end

      def similar_issues(id:, limit: 5)
        issue = Issue.find(id)
        desc = issue.description
        sql = <<-SQL.strip_heredoc
        select mroonga_command(
                 'select',
                 'table', 'searcher_records',
                 'output_columns', 'issue_id, _score',
                 'filter', '(description *S "#{desc}" || notes *S "#{desc}") && in_values(original_type, "Issue", "Journal") && (original_type == "Issue" && original_id != #{id})',
                 'drilldown', 'issue_id',
                 'limit', '#{limit}',
                 'sort_keys', '-_score'
               )
        SQL
        r = connection.select_value(sql)
        # NOTE: Hack to use Groonga::Client::Response.parse
        # Raise Mysql2::Error if error occurred
        body = JSON.parse(r)
        header = [0, 0, 0]
        response = [header, body].to_json
        command = Groonga::Command.find("select").new("select", {})
        r = Groonga::Client::Response.parse(command, response)
        issue_ids = r.records.map do |row|
          row["issue_id"]
        end
        Issue.where(id: issue_ids).all
      end

      def similar_issues2(id:, limit: 5)
        issue = Issue.find(id)
        desc = issue.description
        sql = <<-SQL.strip_heredoc
        select mroonga_command(
                 'select',
                 'table', 'issue_contents',
                 'output_columns', 'issue_id, _score',
                 'filter', '(contents *S "#{desc}") && issue_id != #{id}',
                 'limit', '#{limit}',
                 'sort_keys', '-_score'
               )
        SQL
        r = connection.select_value(sql)
        # NOTE: Hack to use Groonga::Client::Response.parse
        # Raise Mysql2::Error if error occurred
        body = JSON.parse(r)
        header = [0, 0, 0]
        response = [header, body].to_json
        command = Groonga::Command.find("select").new("select", {})
        r = Groonga::Client::Response.parse(command, response)
        issue_ids = r.records.map do |row|
          row["issue_id"]
        end
        p issue_ids
        Issue.where(id: issue_ids).all
      end

      def filter_condition(user, project_ids, scope, attachments, open_issues)
        conditions = _filter_condition(user, project_ids, scope, attachments, open_issues)
        if conditions.empty?
          "1==1"
        else
          %Q[(#{conditions.join(' || ')})]
        end
      end

      def title_digest(name, columns)
        if mroonga_version >= "7.05"
          <<-SQL.strip_heredoc
          'columns[#{name}].stage', 'output',
          'columns[#{name}].type', 'ShortText',
          'columns[#{name}].flags', 'COLUMN_SCALAR',
          'columns[#{name}].value', 'highlight_html(#{columns.join("+")})',
          SQL
        else
          [
            "--columns[#{name}].stage output",
            "--columns[#{name}].type ShortText",
            "--columns[#{name}].flags COLUMN_SCALAR",
            "--columns[#{name}].value \\'highlight_html(#{columns.join("+")})\\'"
          ]
        end
      end

      def description_digest(name, columns)
        if mroonga_version >= "7.05"
          <<-SQL.strip_heredoc
          'columns[#{name}].stage', 'output',
          'columns[#{name}].type', 'ShortText',
          'columns[#{name}].flags', 'COLUMN_VECTOR',
          'columns[#{name}].value', 'snippet_html(#{columns.join("+")}) || vector_new()',
          SQL
        else
          [
            "--columns[#{name}_snippet].stage output",
            "--columns[#{name}_snippet].type ShortText",
            "--columns[#{name}_snippet].flags COLUMN_VECTOR",
            "--columns[#{name}_snippet].value \\'snippet_html(#{columns.join("+")}) || vector_new()\\'"
          ]
        end
      end

      def mroonga_version
        return @mroonga_version if @mroonga_version
        result = connection.execute("show variables like 'mroonga_version'")
        @mroonga_version = result.to_a[0][1]
        @mroonga_version
      end
    end
  end
end
