class ResetSchemaForPgroonga < ActiveRecord::Migration
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
