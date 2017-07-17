class AddIndexToSearcherRecords < ActiveRecord::Migration
  def change
    reversible do |d|
      case
      when Redmine::Database.postgresql?
        opclass = "pgroonga.varchar_full_text_search_ops"
        d.up do
          columns = [
            "id",
            "name #{opclass}",
            "identifier #{opclass}",
            "description",
            "title #{opclass}",
            "summary #{opclass}",
            "subject #{opclass}",
            "comments",
            "content",
            "notes",
            "text",
            "value",
            "filename #{opclass}",
            "original_type #{opclass}"
          ]
          sql = "CREATE INDEX index_searcher_records_pgroonga ON searcher_records USING pgroonga (#{columns.join(',')})"
          execute(sql)
        end
        d.down do
          remove_index(:searcher_records, name: "index_searcher_records_pgroonga")
        end
      when Redmine::Database.mysql?
        columns = %i[
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
          filename
          original_type
        ]
        d.up do
          columns.each do |column|
            add_index(:searcher_records, column, type: "fulltext")
          end
        end
        d.down do
          columns.each do |column|
            remove_index(:searcher_records, column)
          end
        end
      else
        # Do nothing
      end
    end
  end
end
