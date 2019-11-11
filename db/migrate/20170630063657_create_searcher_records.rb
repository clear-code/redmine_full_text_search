require "full_text_search/migration"

class CreateSearcherRecords < ActiveRecord::Migration[4.2]
  def change
    return if reverting? and !table_exists?(:searcher_records)

    if Redmine::Database.mysql?
      options = "ENGINE=Mroonga"
    else
      options = nil
    end
    create_table :searcher_records, options: options do |t|
      # common
      t.integer :project_id, null: false
      t.string :project_name, null: false # for searching by project_name
      t.integer :original_id, null: false
      t.string :original_type, null: false
      t.timestamp :original_created_on
      t.timestamp :original_updated_on

      # projects
      t.string :name
      t.text :description
      t.string :identifier
      t.integer :status

      # news
      t.string :title
      t.string :summary
      # t.text :description

      # issues
      t.string :subject
      # t.text :description
      t.integer :author_id
      t.boolean :is_private
      t.integer :status_id
      t.integer :tracker_id
      t.integer :issue_id

      # documents
      # t.string :title
      # t.text :description

      # changesets
      t.text :comments
      t.text :short_comments
      t.text :long_comments

      # messages
      # t.string :subject
      t.text :content

      # journals
      t.text :notes
      # t.integer :user_id # => author_id
      t.boolean :private_notes
      # t.integer :status_id

      # wiki_pages
      # t.string :title
      t.text :text # wiki_contents.text w/ latest version

      # custom_value
      t.text :value
      t.integer :custom_field_id

      # attachments
      t.integer :container_id
      t.string :container_type
      t.string :filename
      # t.text :description

      t.index([:original_id, :original_type], unique: true)

      columns = [
        :original_type,
        :project_name,
        :name,
        :identifier,
        :description,
        :title,
        :summary,
        :subject,
        :comments,
        :content,
        :notes,
        :text,
        :value,
        :container_type,
        :filename,
      ]
      if Redmine::Database.mysql?
        columns.each do |column|
          t.index column, type: "fulltext"
        end
        t.index :original_type,
                name: "index_searcher_records_on_original_type_perfect_matching"
        t.index :project_id
        t.index :issue_id
      else
        t.index [:id] + columns,
                name: "index_searcher_records_pgroonga",
                using: "PGroonga"
      end
    end
  end
end
