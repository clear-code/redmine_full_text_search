module FullTextSearch
  module PGroonga
    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def search(query, offset: nil, limit: 10, all_words: true)
        unless all_words
          query = query.split(" ").join(" OR ")
        end
        sql = <<-SQL
          select pgroonga.command(
                   'select',
                   ARRAY[
                     'table', pgroonga.table_name('#{index_name}'),
                     'output_columns', '*,_score',
                     'drilldown', 'original_type',
                     'match_columns', '#{target_columns.join(",")}',
                     'query', pgroonga.query_escape('#{query}')
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
    end
  end
end
