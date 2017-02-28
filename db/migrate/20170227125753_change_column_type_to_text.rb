class ChangeColumnTypeToText < ActiveRecord::Migration
  def change
    return unless Redmine::Database.postgresql?
    opclass = "pgroonga.varchar_full_text_search_ops"
    reversible do |d|
      d.up do
        remove_index(:projects, [:id, :name, :identifier, :description])
        remove_index(:news, [:id, :title, :summary, :description])
        remove_index(:issues, [:id, :subject, :description])
        remove_index(:documents, [:id, :title, :description])
        remove_index(:messages, [:id, :subject, :content])
        remove_index(:wiki_pages, [:id, :title])
        remove_index(:attachments, [:id, :filename, :description])

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
      d.down do
        remove_index(:projects, name: "index_projects_pgroonga")
        remove_index(:news, name: "index_news_pgroonga")
        remove_index(:issues, name: "index_issues_pgroonga")
        remove_index(:documents, name: "index_documents_pgroonga")
        remove_index(:messages, name: "index_messages_pgroonga")
        remove_index(:wiki_pages, name: "index_wiki_pages_pgroonga")
        remove_index(:attachments, name: "index_attachments_pgroonga")

        add_index(:projects, [:id, :name, :identifier, :description], using: "pgroonga")
        add_index(:news, [:id, :title, :summary, :description], using: "pgroonga")
        add_index(:issues, [:id, :subject, :description], using: "pgroonga")
        add_index(:documents, [:id, :title, :description], using: "pgroonga")
        add_index(:messages, [:id, :subject, :content], using: "pgroonga")
        add_index(:wiki_pages, [:id, :title], using: "pgroonga")
        add_index(:attachments, [:id, :filename, :description], using: "pgroonga")
      end
    end
  end
end
