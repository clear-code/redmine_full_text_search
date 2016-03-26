class CreateIndexForFullTextSearch < ActiveRecord::Migration
  def up
    case
    when Redmine::Database.postgresql?
      enable_extension("pgroonga")
      add_index(:projects, [:id, :name, :identifier, :description], using: "pgroonga")
      add_index(:news, [:id, :title, :summary, :description], using: "pgroonga")
      add_index(:issues, [:id, :subject, :description], using: "pgroonga")
      add_index(:documents, [:id, :title, :description], using: "pgroonga")
      add_index(:changesets, [:id, :comments], using: "pgroonga")
      add_index(:messages, [:id, :subject, :content], using: "pgroonga")
      add_index(:journals, [:id, :notes], using: "pgroonga")
      add_index(:wiki_pages, [:id, :title], using: "pgroonga")
      add_index(:wiki_contents, [:id, :text], using: "pgroonga")
      add_index(:custom_values, [:id, :value], using: "pgroonga")
      add_index(:attachments, [:id, :filename, :description], using: "pgroonga")
    when Redmine::Database.mysql?
      create_table(:fts_projects, options: "ENGINE=Mroonga") do |t|
        t.references :project, index: true
        t.string :name
        t.string :identifier
        t.text :description, limit: 65535
      end
      create_table(:fts_news, options: "ENGINE=Mroonga") do |t|
        t.references :news, index: true
        t.string :title, limit: 60, default: "", null: false
        t.string :summary, default: ""
        t.text :description, limit: 65535
      end
      create_table(:fts_issues, options: "ENGINE=Mroonga") do |t|
        t.references :issue, index: true
        t.string :subject, default: "", null: false
        t.text :description, limit: 65535
      end
      create_table(:fts_documents, options: "ENGINE=Mroonga") do |t|
        t.references :document, index: true
        t.string :title, default: "", null: false
        t.text :description, limit: 65535
      end
      create_table(:fts_changesets, options: "ENGINE=Mroonga") do |t|
        t.references :changeset, index: true
        t.text :comments, limit: 4294967295
      end
      create_table(:fts_messages, options: "ENGINE=Mroonga") do |t|
        t.references :message, index: true
        t.string :subject, default: "", null: false
        t.text :content, limit: 65535
      end
      create_table(:fts_journals, options: "ENGINE=Mroonga") do |t|
        t.references :journal, index: true
        t.text :notes, limit: 65535
      end
      create_table(:fts_attachments, options: "ENGINE=Mroonga") do |t|
        t.references :attachment, index: true
        t.string :filename, default: "", null: false
        t.string :description
      end
      create_table(:fts_wiki_pages, options: "ENGINE=Mroonga") do |t|
        t.references :wiki_page, index: true
        t.string :title, null: false
      end
      create_table(:fts_wiki_contents, options: "ENGINE=Mroonga") do |t|
        t.references :wiki_content, index: true
        t.text :text, limit: 4294967295
      end
      create_table(:fts_custom_values, options: "ENGINE=Mroonga") do |t|
        t.references :custom_value, index: true
        t.text :value, limit: 65535
      end

      sql = <<-SQL
        INSERT INTO fts_projects(project_id, name, identifier, description) SELECT id, name, identifier, description FROM projects;
        INSERT INTO fts_news(news_id, title, summary, description) SELECT id, title, summary, description FROM news;
        INSERT INTO fts_issues(issue_id, subject, description) SELECT id, subject, description FROM issues;
        INSERT INTO fts_documents(document_id, title, description) SELECT id, title, description FROM documents;
        INSERT INTO fts_changesets(changeset_id, comments) SELECT id, comments FROM changesets;
        INSERT INTO fts_messages(message_id, subject, content) SELECT id, subject, content FROM messages;
        INSERT INTO fts_journals(journal_id, notes) SELECT id, notes FROM journals;
        INSERT INTO fts_attachments(attachment_id, filename, description) SELECT id, filename, description from attachments;
        INSERT INTO fts_wiki_pages(wiki_page_id, title) SELECT id, title FROM wiki_pages;
        INSERT INTO fts_wiki_contents(wiki_content_id, `text`) SELECT id, `text` FROM wiki_contents;
        INSERT INTO fts_custom_values(custom_value_id, value) SELECT id, value FROM custom_values;
      SQL
      execute(sql)

      add_index(:fts_projects, [:name, :identifier, :description], type: "fulltext")
      add_index(:fts_news, [:title, :summary, :description], type: "fulltext")
      add_index(:fts_issues, [:subject, :description], type: "fulltext")
      add_index(:fts_documents, [:title, :description], type: "fulltext")
      add_index(:fts_changesets, :comments, type: "fulltext")
      add_index(:fts_messages, [:subject, :content], type: "fulltext")
      add_index(:fts_journals, :notes, type: "fulltext")
      add_index(:fts_attachments, [:filename, :description], type: "fulltext")
      add_index(:fts_wiki_pages, :title, type: "fulltext")
      add_index(:fts_wiki_contents, :text, type: "fulltext")
      add_index(:fts_custom_values, :value, type: "fulltext")

      # Reconstruct fulltext index
      sql = %w[
        projects
        news
        issues
        documents
        changesets
        messages
        journals
        attachments
        wiki_pages
        wiki_contents
      ].inject("") do |memo, table|
        memo += <<-SQL
          ALTER TABLE fts_#{table} DISABLE KEYS;
          ALTER TABLE fts_#{table} ENABLE KEYS;
        SQL
      end
      execute(sql)
    else
      # Do nothing
    end
  end

  def down
    case
    when Redmine::Database.postgresql?
      remove_index(:projects, column: [:id, :name, :identifier, :description])
      remove_index(:news, column: [:id, :title, :summary, :description])
      remove_index(:issues, column: [:id, :subject, :description])
      remove_index(:documents, column: [:id, :title, :description])
      remove_index(:changesets, column: [:id, :comments])
      remove_index(:messages, column: [:id, :subject, :content])
      remove_index(:journals, column: [:id, :notes])
      remove_index(:attachments, column: [:id, :filename, :description])
      remove_index(:wiki_pages, column: [:id, :title])
      remove_index(:wiki_contents, column: [:id, :text])
      remove_index(:custom_values, column: [:id, :value])
      disable_extension("pgroonga")
    when Redmine::Database.mysql?
      remove_index(:fts_projects, column: [:name, :identifier, :description])
      remove_index(:fts_news, column: [:title, :summary, :description])
      remove_index(:fts_issues, column: [:subject, :description])
      remove_index(:fts_documents, column: [:title, :description])
      remove_index(:fts_changesets, column: :comments)
      remove_index(:fts_messages, column: [:subject, :content])
      remove_index(:fts_journals, column: :notes)
      remove_index(:fts_attachments, column: [:filename, :description])
      remove_index(:fts_wiki_pages, column: :title)
      remove_index(:fts_wiki_contents, column: :text)
      remove_index(:fts_custom_values, column: :value)

      drop_table(:fts_projects)
      drop_table(:fts_news)
      drop_table(:fts_issues)
      drop_table(:fts_documents)
      drop_table(:fts_changesets)
      drop_table(:fts_messages)
      drop_table(:fts_journals)
      drop_table(:fts_attachments)
      drop_table(:fts_wiki_pages)
      drop_table(:fts_wiki_contents)
      drop_table(:fts_custom_values)
    else
      # Do nothing
    end
  end
end
