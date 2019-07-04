migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class DropSearcherRecords < migration
  def change
    reversible do |d|
      d.up do
        drop_table :searcher_records
      end
      d.down do
        create_table :searcher_records do |t|
          if Redmine::Database.mysql?
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

            t.index :original_type, type: "fulltext"
            t.index :project_name, type: "fulltext"
            t.index :name, type: "fulltext"
            t.index :identifier, type: "fulltext"
            t.index :description, type: "fulltext"
            t.index :title, type: "fulltext"
            t.index :summary, type: "fulltext"
            t.index :subject, type: "fulltext"
            t.index :comments, type: "fulltext"
            t.index :content, type: "fulltext"
            t.index :notes, type: "fulltext"
            t.index :text, type: "fulltext"
            t.index :value, type: "fulltext"
            t.index :container_type, type: "fulltext"
            t.index :filename, type: "fulltext"
            t.index :original_type, name: "index_searcher_records_on_original_type_perfect_matching"
            t.index :project_id
            t.index :issue_id
            t.index :short_comments, type: "fulltext"
            t.index :long_comments, type: "fulltext"
          elsif Redmine::Database.postgresql?
            t.index :id, name: "index_searcher_records_pgroonga"
          end
        end
      end
    end
  end
end
