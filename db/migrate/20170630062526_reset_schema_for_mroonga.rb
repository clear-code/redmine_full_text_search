class ResetSchemaForMroonga < ActiveRecord::Migration
  def change
    return unless Redmine::Database.mysql?
    drop_table(:fts_projects, if_exists: true)
    drop_table(:fts_news, if_exists: true)
    drop_table(:fts_issues, if_exists: true)
    drop_table(:fts_journals, if_exists: true)
    drop_table(:fts_documents, if_exists: true)
    drop_table(:fts_messages, if_exists: true)
    drop_table(:fts_attachments, if_exists: true)
    drop_table(:fts_changesets, if_exists: true)
    drop_table(:fts_wiki_pages, if_exists: true)
    drop_table(:fts_wiki_contents, if_exists: true)
    drop_table(:fts_custom_values, if_exists: true)
  end
end
