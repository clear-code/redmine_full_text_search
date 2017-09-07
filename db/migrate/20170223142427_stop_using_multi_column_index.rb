class StopUsingMultiColumnIndex < ActiveRecord::Migration
  def up
    return unless Redmine::Database.mysql?
    remove_index(:fts_projects, [:name, :identifier, :description])
    remove_index(:fts_news, [:title, :summary, :description])
    remove_index(:fts_issues, [:subject, :description])
    remove_index(:fts_documents, [:title, :description])
    remove_index(:fts_messages, [:subject, :content])
    remove_index(:fts_attachments, [:filename, :description])

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

  def down
    return unless Redmine::Database.mysql?
    remove_index(:fts_projects, :name) if index_exists?(:fts_projects, :name)
    remove_index(:fts_projects, :identifier) if index_exists?(:fts_projects, :identifier)
    remove_index(:fts_projects, :description) if index_exists?(:fts_projects, :description)
    remove_index(:fts_news, :title) if index_exists?(:fts_news, :title)
    remove_index(:fts_news, :summary) if index_exists?(:fts_news, :summary)
    remove_index(:fts_news, :description) if index_exists?(:fts_news, :description)
    remove_index(:fts_issues, :subject) if index_exists?(:fts_issues, :subject)
    remove_index(:fts_issues, :description) if index_exists?(:fts_issues, :description)
    remove_index(:fts_documents, :title) if index_exists?(:fts_documents, :title)
    remove_index(:fts_documents, :description) if index_exists?(:fts_documents, :description)
    remove_index(:fts_messages, :subject) if index_exists?(:fts_messages, :subject)
    remove_index(:fts_messages, :content) if index_exists?(:fts_messages, :content)
    remove_index(:fts_attachments, :filename) if index_exists?(:fts_attachments, :filename)
    remove_index(:fts_attachments, :description) if index_exists?(:fts_attachments, :description)

    if [:name, :identifier, :description].all? {|col| column_exists?(:fts_projects, col) }
      add_index(:fts_projects, [:name, :identifier, :description], type: "fulltext")
    end
    if [:title, :summary, :description].all? {|col| column_exists?(:fts_news, col) }
      add_index(:fts_news, [:title, :summary, :description], type: "fulltext")
    end
    if [:subject, :description].all? {|col| column_exists?(:fts_issues, col) }
      add_index(:fts_issues, [:subject, :description], type: "fulltext")
    end
    if [:title, :description].all? {|col| column_exists?(:fts_documents, col) }
      add_index(:fts_documents, [:title, :description], type: "fulltext")
    end
    if [:subject, :content].all? {|col| column_exists?(:fts_messages, col) }
      add_index(:fts_messages, [:subject, :content], type: "fulltext")
    end
    if [:filename, :description].all? {|col| column_exists?(:fts_attachments, col) }
      add_index(:fts_attachments, [:filename, :description], type: "fulltext")
    end
  end
end
