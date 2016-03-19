class CreateIndexForFullTextSearch < ActiveRecord::Migration
  def up
    case
    when Redmine::Database.postgresql?
      enable_extension("pgroonga")
      add_index(:projects, [:name, :identifier, :description], using: "pgroonga")
      add_index(:news, [:title, :summary, :description], using: "pgroonga")
      add_index(:issues, [:subject, :description], using: "pgroonga")
      add_index(:documents, [:title, :description], using: "pgroonga")
      add_index(:changesets, :comments, using: "pgroonga")
      add_index(:messages, [:subject, :content], using: "pgroonga")
      add_index(:journals, :notes, using: "pgroonga")
      add_index(:wiki_pages, :title, using: "pgroonga")
      add_index(:wiki_contents, :text, using: "pgroonga")
      add_index(:custom_values, :value, using: "pgroonga")
    when Redmine::Database.mysql?
      %w[projects news issues documents changesets messages journals wiki_pages wiki_contents custom_values].each do |name|
        execute "ALTER TABLE #{name} ENGINE = Mroonga;"
      end
      add_index(:projects, [:name, :identifier, :description], type: "fulltext")
      add_index(:news, [:title, :summary, :description], type: "fulltext")
      add_index(:issues, [:subject, :description], type: "fulltext")
      add_index(:documents, [:title, :description], type: "fulltext")
      add_index(:changesets, :comments, type: "fulltext")
      add_index(:messages, [:subject, :content], type: "fulltext")
      add_index(:journals, :notes, type: "fulltext")
      add_index(:wiki_pages, :title, type: "fulltext")
      add_index(:wiki_contents, :text, type: "fulltext")
      add_index(:custom_values, :value, type: "fulltext")
    else
      # Do nothing
    end
  end

  def down
    case
    when Redmine::Database.postgresql?
      remove_index(:projects, column: [:name, :identifier, :description])
      remove_index(:news, column: [:title, :summary, :description])
      remove_index(:issues, column: [:subject, :description])
      remove_index(:documents, column: [:title, :description])
      remove_index(:changesets, column: :comments)
      remove_index(:messages, column: [:subject, :content])
      remove_index(:journals, column: :notes)
      remove_index(:wiki_pages, column: :title)
      remove_index(:wiki_contents, column: :text)
      remove_index(:custom_values, column: :value)
      disable_extension("pgroonga")
    when Redmine::Database.mysql?
      remove_index(:projects, column: [:name, :identifier, :description])
      remove_index(:news, column: [:title, :summary, :description])
      remove_index(:issues, column: [:subject, :description])
      remove_index(:documents, column: [:title, :description])
      remove_index(:changesets, column: :comments)
      remove_index(:messages, column: [:subject, :content])
      remove_index(:journals, column: :notes)
      remove_index(:wiki_pages, column: :title)
      remove_index(:wiki_contents, column: :text)
      remove_index(:custom_values, column: :value)
      %w[projects news issues documents changesets messages jounals wiki_pages wiki_contents custom_values].each do |name|
        execute "ALTER TABLE #{name} ENGINE = InnoDB;"
      end
    else
      # Do nothing
    end
  end
end
