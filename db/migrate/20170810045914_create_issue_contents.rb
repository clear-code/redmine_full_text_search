migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class CreateIssueContents < migration
  def change
    reversible do |d|
      d.up do
        case
        when Redmine::Database.postgresql?
          create_table :issue_contents do |t|
            t.integer :project_id
            t.integer :issue_id, unique: true, null: false
            t.string :subject
            t.text :contents
            t.integer :status_id
            t.boolean :is_private
          end
        when Redmine::Database.mysql?
          create_table :issue_contents, options: "ENGINE=Mroonga" do |t|
            t.integer :project_id
            t.integer :issue_id, unique: true, null: false
            t.string :subject
            t.text :contents, limit: 16.megabytes
            t.integer :status_id
            t.boolean :is_private
          end
        end
      end
      d.down do
        drop_table :issue_contents
      end
    end
  end
end
