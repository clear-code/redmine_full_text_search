module FullTextSearch
  module PGroonga
    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
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
        scope.select("pgroonga.score(#{self.table_name}) AS score", :id)
          .reorder("score DESC", id: :desc)
          .distinct
          .limit(limit)
          .map do |record|
          [record.score, record.id]
        end
      end
    end
  end
end
