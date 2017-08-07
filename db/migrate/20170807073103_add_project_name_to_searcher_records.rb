class AddProjectNameToSearcherRecords < ActiveRecord::Migration
  def change
    reversible do |d|
      d.up do
        add_column(:searcher_records, :project_name, :string)
        case
        when Redmine::Database.postgresql?
          remove_index(:searcher_records, name: "index_searcher_records_pgroonga")
          opclass = "pgroonga.varchar_full_text_search_ops"
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
          sql = "UPDATE searcher_records AS s SET project_name = p.name FROM projects as p WHERE s.project_id = p.id"
          execute(sql)
        when Redmine::Database.mysql?
          add_index(:searcher_records, :project_name, type: "fulltext")
          sql = "UPDATE searcher_records AS s JOIN projects AS p ON (s.project_id = p.id) SET project_name = p.name"
          execute(sql)
        end
      end

      d.down do
        case
        when Redmine::Database.postgresql?
          remove_index(:searcher_records, name: "index_searcher_records_pgroonga")
          columns = [
            "id",
            "project_id",
            "original_id",
            "original_type",
            "original_created_on",
            "original_updated_on",
            "name #{opclass}",
            "identifier #{opclass}",
            "description",
            "title #{opclass}",
            "summary #{opclass}",
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
        when Redmine::Database.mysql?
          remove_index(:searcher_recoreds, :project_name)
        end
        remove_column(:searcher_records, :project_name)
      end
    end
  end
end
