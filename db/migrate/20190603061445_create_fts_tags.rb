migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class CreateFtsTags < migration
  def change
    if Redmine::Database.mysql?
      options = "ENGINE=Mroonga"
    else
      options = nil
    end
    create_table :fts_tags, options: options do |t|
      t.integer :type_id, null: false
      t.string :name, null: false
      t.index [:type_id, :name], unique: true
    end
  end
end
