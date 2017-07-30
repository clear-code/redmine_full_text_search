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
                 offset: nil,
                 limit: 10,
                 order_target: "score",
                 order_type: "desc")
        unless all_words
          query = query.split(" ").join(" OR ")
        end
        # mroonga_command cannot contain new line
        # mroonga_command can accept multiple arguments since 7.0.5
        sql = [
          "select mroonga_command(",
          "'select --table searcher_records",
          "--output_columns *,_score",
          "--drilldown original_type",
          "--match_columns #{target_columns.join('||')}",
          "--query \"#{query}\"",
          "--filter #{filter_condition(user, project_ids, scope, attachments)}",
          "'",
          ")"
        ].join(" ")
        connection.select_value(sql)
      end
    end
  end
end
