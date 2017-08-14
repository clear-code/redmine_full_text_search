module FullTextSearch
  module SimilarSearcher
    module Mroonga
      def self.included(base)
        base.include(InstanceMethods)
      end

      module InstanceMethods
        def similar_issues(user: User.current, limit: 5)
          desc = [subject, description, journals.sort_by(&:id).map(&:notes)].flatten.join("\n")
          sql = <<-SQL.strip_heredoc
          select mroonga_command(
                   'select',
                   'table', 'issue_contents',
                   'output_columns', 'issue_id, _score',
                   'filter', CONCAT('(contents *S "', mroonga_escape(:desc), '") && issue_id != :id'),
                   'limit', ':limit',
                   'sort_keys', '-_score'
                 )
          SQL
          r = self.class.connection.select_value(ActiveRecord::Base.send(:sanitize_sql_array, [sql, desc: desc, id: id, limit: limit]))
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
          logger.debug(r.records)
          Issue.where(id: issue_ids).all
        rescue => ex
          if Rails.env.production?
            logger.warn(ex.class => ex.message)
            []
          else
            raise
          end
        end
      end
    end
  end
end
