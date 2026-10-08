require_relative "migration"

module FullTextSearch
  class SemanticIndex
    INDEX_NAME = "fts_targets_semantic_index_pgroonga"
    # The column for the semantic search.
    CONTENT_COLUMN = "content"

    class << self
      def available?
        Redmine::Database.postgresql?
      end

      def exist?
        return false unless available?
        connection.select_value(
          "SELECT to_regclass(#{connection.quote(INDEX_NAME)})::text"
        ).present?
      end

      def table_name
        Target.table_name
      end

      def index_columns
        [CONTENT_COLUMN] | Target.column_names
      end

      def ensure_created(concurrently: false)
        return false unless available?
        return :exist if exist?
        connection.add_index(
          table_name,
          index_columns,
          name: INDEX_NAME,
          using: :pgroonga,
          opclass: {CONTENT_COLUMN => :pgroonga_text_semantic_search_ops_v2},
          with: build_with,

          # Even empty strings generate vectors and have their distances calculated.
          # Since this generates meaningless vectors, it will be excluded.
          where: "#{CONTENT_COLUMN} != ''",

          algorithm: (concurrently ? :concurrently : nil),
          if_not_exists: true
        )
        :created
      end

      def ensure_dropped(concurrently: false)
        return false unless available?
        connection.remove_index(
          table_name,
          name: INDEX_NAME,
          if_exists: true,
          algorithm: (concurrently ? :concurrently : nil)
        )
        true
      end

      def model
        settings.semantic_model
      end

      private

      def settings
        Setting.plugin_full_text_search
      end

      def build_with
        options = [
          "plugins = #{connection.quote('language_model/knn')}",
          "model = #{connection.quote(settings.semantic_model)}",
        ]
        if settings.semantic_passage_prefix
          options << "passage_prefix = #{connection.quote(settings.semantic_passage_prefix)}"
        end
        if settings.semantic_query_prefix
          options << "query_prefix = #{connection.quote(settings.semantic_query_prefix)}"
        end
        options.join(",")
      end

      def connection
        ActiveRecord::Base.connection
      end
    end
  end
end
