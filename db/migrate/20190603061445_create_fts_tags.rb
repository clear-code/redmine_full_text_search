class CreateFtsTags < ActiveRecord::Migration[5.2]
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
