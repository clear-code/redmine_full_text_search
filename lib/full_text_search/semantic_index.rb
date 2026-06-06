require_relative "migration"

module FullTextSearch
  class SemanticIndex
    INDEX_NAME = "fts_targets_semantic_index_pgroonga"

    INDEX_COLUMNS = [
      "id",
      "source_id",
      "source_type_id",
      "project_id",
      "container_id",
      "container_type_id",
      "custom_field_id",
      "is_private",
      "last_modified_at",
      "registered_at",
      "title",
      "tag_ids"
    ]

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

      def ensure_created(concurrently: false)
        return false unless available?
        return :exist if exist?
        connection.add_index(
          table_name,
          ["content", *INDEX_COLUMNS],
          name: INDEX_NAME,
          using: :pgroonga,
          opclass: {content: :pgroonga_text_semantic_search_ops_v2},
          with: build_with,
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
