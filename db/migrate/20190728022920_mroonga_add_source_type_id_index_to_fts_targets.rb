class MroongaAddSourceTypeIdIndexToFtsTargets < ActiveRecord::Migration[5.2]
  def change
    if Redmine::Database.mysql?
      add_index :fts_targets, :source_type_id
    end
  end
end
