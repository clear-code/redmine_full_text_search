module FullTextSearch
  module SimilarSearcher
    module PGroonga
      def self.included(base)
        base.include(InstanceMethods)
      end

      module InstanceMethods
        def similar_issues(user: User.current, limit: 5)
          desc = [subject, description, journals.sort_by(&:id).map(&:notes)].flatten.join("\n")
          sql = <<-SQL.strip_heredoc
          select pgroonga.command(
                   'select',
                   ARRAY[
                     'table', pgroonga.table_name('#{similar_issues_index_name}'),
                     'output_columns', 'issue_id, _score',
                     'filter', '(contents *S ' || pgroonga.escape(:desc) || ') && issue_id != :id',
                     'limit', ':limit',
                     'sort_keys', '-_score'
                   ]
                 )::json
          SQL
          response = self.class.connection.select_value(ActiveRecord::Base.send(:sanitize_sql_array, [sql, desc: desc, id: id, limit: limit]))
          command = Groonga::Command.find("select").new("select", {})
          r = Groonga::Client::Response.parse(command, response)
          if r.success?
            issue_ids = r.records.map do |row|
              row["issue_id"]
            end
            Issue.where(id: issue_ids).all
          else
            if Rails.env.production?
              logger.warn(r.message)
              []
            else
              raise r.message
            end
          end
        end

        def similar_issues_index_name
          "index_issue_contents_pgroonga"
        end
      end
    end
  end
end
