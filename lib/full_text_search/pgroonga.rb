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
                 project_ids: [],
                 offset: nil,
                 limit: 10,
                 all_words: true,
                 order_target: "score",
                 order_type: "desc")
        unless all_words
          query = query.split(" ").join(" OR ")
        end
        project_condition = if project_ids.empty?
                              ""
                            else
                              " && in_values(project_id, #{project_ids}.join(', '))"
                            end
        sort_direction = order_type == "desc" ? "-" : ""
        sort_keys = case order_target
                    when "score"
                      "#{sort_direction}_score"
                    when "date"
                      "#{sort_direction}original_updated_on, #{sort_direction}original_created_on"
                    end
        sql = <<-SQL
          select pgroonga.command(
                   'select',
                   ARRAY[
                     'table', pgroonga.table_name('#{index_name}'),
                     'output_columns', '*,_score',
                     'drilldown', 'original_type',
                     'match_columns', '#{target_columns.join(",")}',
                     'query', pgroonga.query_escape('#{query}'),
                     'filter', 'pgroonga_tuple_is_alive(ctid)#{project_condition}',
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
    end
  end
end
