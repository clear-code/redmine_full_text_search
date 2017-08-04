class ResetSchemaForPgroonga < ActiveRecord::Migration
  def change
    return unless Redmine::Database.postgresql?
    opclass = "pgroonga.varchar_full_text_search_ops"
    reversible do |d|
      d.up do
        remove_index(:projects, name: "index_projects_pgroonga")
        remove_index(:news, name: "index_news_pgroonga")
        remove_index(:issues, name: "index_issues_pgroonga")
        remove_index(:documents, name: "index_documents_pgroonga")
        remove_index(:messages, name: "index_messages_pgroonga")
        remove_index(:wiki_pages, name: "index_wiki_pages_pgroonga")
        remove_index(:attachments, name: "index_attachments_pgroonga")
      end
      d.down do
        [
          [:projects, "id, name #{opclass}, identifier #{opclass}, description"],
          [:news, "id, title #{opclass}, summary #{opclass}, description"],
          [:issues, "id, subject #{opclass}, description"],
          [:documents, "id, title #{opclass}, description"],
          [:messages, "id, subject #{opclass}, content"],
          [:wiki_pages, "id, title #{opclass}"],
          [:attachments, "id, filename #{opclass}, description"],
        ].each do |table, columns|
          sql = "CREATE INDEX index_#{table}_pgroonga ON #{table} USING pgroonga (#{columns})"
          execute(sql)
        end
      end
    end
  end
end
