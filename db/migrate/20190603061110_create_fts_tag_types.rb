class CreateFtsTagTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :fts_tag_types do |t|
      t.string :name, null: false
      t.index :name, unique: true
    end
  end
end
