module FullTextSearch
  module PGroonga
    def search(query, **kw)
    end

    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def search_result_ranks_and_ids(tokens, user=User.current, projects=nil, options={})
        params = options.fetch(:params, {})
        @order_target = params[:order_target] || "score"
        r = super
        r = r.group_by {|_score, id| id }
        r = r.map {|id, origs| [origs.sum {|s, _| s }, id] }
        r
      end

      # Overwrite ActsAsSearchable
      def search_tokens_condition(columns, tokens, all_words)
        token_clauses = columns.map do |column|
          "#{column} @@ ?"
        end
        sql = token_clauses.join(' OR ')
        [sql, *([tokens.join(all_words ? " " : " OR ")] * columns.size)]
      end

      # Overwrite ActsAsSearchable
      def fetch_ranks_and_ids(scope, limit)
        target_column_name = "#{table_name}.#{order_column_name}"
        scope.select("pgroonga.score(#{self.table_name}) AS score, #{target_column_name} AS order_target", :id)
          .reorder("score DESC", id: :desc)
          .distinct
          .limit(limit)
          .map do |record|
          if @order_target == "score"
            [record.score, record.id]
          else
            [record.order_target.to_i, record.id]
          end
        end
      end

      #
      # searchable_options[:date_column] is not enough
      # Because almost all models does not use `acts_as_searchable :date_column` option,
      # and searchable_options[:data] default value is `:created_on`
      #
      def order_column_name
        timestamp_columns = ["created_on", "updated_on", "commited_on"]
        column_names.select {|column_name| timestamp_columns.include?(column_name) }.sort.last || "id"
      end
    end
  end
end
