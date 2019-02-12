migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class CreateSearcherRecords < migration
  def change
    reversible do |d|
      d.up do
        case
        when Redmine::Database.postgresql?
          create_table :searcher_records do |t|
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

            t.index([:original_id, :original_type], name: "index_searcher_records_unique", unique: true)
          end
        when Redmine::Database.mysql?
          create_table :searcher_records, options: "ENGINE=Mroonga" do |t|
            # common
            t.integer :project_id, null: false
            t.string :project_name, null: false # for searching by project_name
            t.integer :original_id, null: false
            t.string :original_type, null: false, limit: 30
            t.timestamp :original_created_on
            t.timestamp :original_updated_on

            # projects
            t.string :name
            t.text :description, limit: 16.megabytes
            t.string :identifier
            t.integer :status

            # news
            t.string :title
            t.string :summary
            # t.text :description

            # issues
            t.integer :tracker_id
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
            t.text :comments, limit: 16.megabytes
            t.text :short_comments, limit: 16.megabytes
            t.text :long_comments, limit: 16.megabytes

            # messages
            # t.string :subject
            t.text :content

            # journals
            t.text :notes, limit: 16.megabytes
            # t.integer :user_id # => author_id
            t.boolean :private_notes
            # t.integer :status_id

            # wiki_pages
            # t.string :title
            t.text :text, limit: 16.megabytes # wiki_contents.text w/ latest version

            # custom_value
            t.text :value, limit: 16.megabytes
            t.integer :custom_field_id

            # attachments
            t.integer :container_id
            t.string :container_type, limit: 30
            t.string :filename, limit: 255
            # t.text :description

            t.index([:original_id, :original_type], name: "index_searcher_records_unique", unique: true)
          end
        end
      end
      d.down do
        drop_table :searcher_records
      end
    end
  end
end
