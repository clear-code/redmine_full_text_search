module FullTextSearch
  module SimilarSearcher
    module Mroonga
      def self.included(base)
        base.include(InstanceMethods)
        base.include(FullTextSearch::ConditionBuilder)
        base.class_eval do
          attr_accessor :similarity_score
        end
      end

      module InstanceMethods
        def similar_issues(user: User.current, project_ids: [], limit: 5)
          sql = <<-SQL.strip_heredoc
          select mroonga_command(
                   'select',
                   'table', 'issue_contents',
                   'output_columns', 'issue_id, _score',
                   'filter', CONCAT('(content *S "', mroonga_escape(:term), '") && issue_id != ', :id, ' && #{filter_condition(user, project_ids)}'),
                   'limit', :limit,
                   'sort_keys', '-_score'
                 )
          SQL
          r = nil
          ActiveSupport::Notifications.instrument("groonga.similar.search", sql: sql) do
            r = self.class.connection.select_value(ActiveRecord::Base.send(:sanitize_sql_array, [sql, term: similar_term, id: id.to_s, limit: limit.to_s]))
          end
          # NOTE: Hack to use Groonga::Client::Response.parse
          # Raise Mysql2::Error if error occurred
          body = JSON.parse(r)
          header = [0, 0, 0]
          response = [header, body].to_json
          command = Groonga::Command.find("select").new("select", {})
          r = Groonga::Client::Response.parse(command, response)
          issue_scores = r.records.map do |row|
            [row["issue_id"], row["_score"]]
          end.to_h
          logger.debug(r.records)
          similar_issues = Issue.where(id: issue_scores.keys).all
          similar_issues.each do |s|
            s.similarity_score = issue_scores[s.id]
          end
          similar_issues.sort_by {|s| - s.similarity_score }
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
