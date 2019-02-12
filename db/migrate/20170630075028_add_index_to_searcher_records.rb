migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class AddIndexToSearcherRecords < migration
  def change
    reversible do |d|
      case
      when Redmine::Database.postgresql?
        opclass = "pgroonga_varchar_full_text_search_ops_v2"
        d.up do
          columns = [
            "id",
            "project_id",
            "project_name #{opclass}",
            "original_id",
            "original_type",
            "original_created_on",
            "original_updated_on",
            "name #{opclass}",
            "identifier #{opclass}",
            "description",
            "title #{opclass}",
            "summary #{opclass}",
            "issue_id",
            "subject #{opclass}",
            "is_private",
            "status_id",
            "comments",
            "short_comments",
            "long_comments",
            "content",
            "notes",
            "private_notes",
            "text",
            "value",
            "custom_field_id",
            "container_id",
            "container_type",
            "filename #{opclass}",
          ]
          sql = "CREATE INDEX index_searcher_records_pgroonga ON searcher_records USING pgroonga (#{columns.join(',')})"
          execute(sql)
        end
        d.down do
          remove_index(:searcher_records, name: "index_searcher_records_pgroonga")
        end
      when Redmine::Database.mysql?
        columns = %i[
          original_type
          project_name
          name
          identifier
          description
          title
          summary
          subject
          comments
          content
          notes
          text
          value
          container_type
          filename
        ]
        d.up do
          columns.each do |column|
            add_index(:searcher_records, column, type: "fulltext")
          end
          add_index(:searcher_records, "original_type", name: "index_searcher_records_on_original_type_perfect_matching")
          add_index(:searcher_records, "project_id")
          add_index(:searcher_records, "issue_id")
        end
        d.down do
          columns.each do |column|
            remove_index(:searcher_records, column)
          end
          remove_index(:searcher_records, name: "index_searcher_records_on_original_type_perfect_matching")
          remove_index(:searcher_records, "project_id")
          remove_index(:searcher_records, "issue_id")
        end
      else
        # Do nothing
      end
    end
  end
end
