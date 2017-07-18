module FullTextSearch
  module Mroonga
    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def search(query, **kw)
        unless all_words
          query = query.split(" ").join(" OR ")
        end
        # mroonga_command cannot contain new line
        # FIXME: escape query
        sql = [
          "select mroonga_command(",
          "'select --table searcher_records",
          "--output_columns *,_score",
          "--drilldown original_type",
          "--match_columns #{target_columns.join(',')}",
          "--query \"#{query}\"",
          "'",
          ")"
        ].join(" ")
        connection.select_value(sql)
      end
    end
  end
end
