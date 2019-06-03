migration = ActiveRecord::Migration
migration = migration[4.2] if migration.respond_to?(:[])
class CreateFtsTagTypes < migration
  def change
    create_table :fts_tag_types do |t|
      t.string :name, null: false
      t.index :name, unique: true
    end
  end
end
