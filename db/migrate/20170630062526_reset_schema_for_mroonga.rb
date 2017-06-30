class ResetSchemaForMroonga < ActiveRecord::Migration
  def change
    return unless Redmine::Database.mysql?
    reversible do |d|
      d.up do
        remove_index(:fts_projects, :name)
        remove_index(:fts_projects, :identifier)
        remove_index(:fts_projects, :description)
        remove_index(:fts_news, :title)
        remove_index(:fts_news, :summary)
        remove_index(:fts_news, :description)
        remove_index(:fts_issues, :subject)
        remove_index(:fts_issues, :description)
        remove_index(:fts_documents, :title)
        remove_index(:fts_documents, :description)
        remove_index(:fts_messages, :subject)
        remove_index(:fts_messages, :content)
        remove_index(:fts_attachments, :filename)
        remove_index(:fts_attachments, :description)
      end
      d.down do
        add_index(:fts_projects, :name, type: "fulltext")
        add_index(:fts_projects, :identifier, type: "fulltext")
        add_index(:fts_projects, :description, type: "fulltext")
        add_index(:fts_news, :title, type: "fulltext")
        add_index(:fts_news, :summary, type: "fulltext")
        add_index(:fts_news, :description, type: "fulltext")
        add_index(:fts_issues, :subject, type: "fulltext")
        add_index(:fts_issues, :description, type: "fulltext")
        add_index(:fts_documents, :title, type: "fulltext")
        add_index(:fts_documents, :description, type: "fulltext")
        add_index(:fts_messages, :subject, type: "fulltext")
        add_index(:fts_messages, :content, type: "fulltext")
        add_index(:fts_attachments, :filename, type: "fulltext")
        add_index(:fts_attachments, :description, type: "fulltext")
      end
    end
  end
end
