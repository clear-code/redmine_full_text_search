class MroongaAddSourceTypeIdIndexToFtsTargets < ActiveRecord::Migration[5.2]
  def change
    return if reverting? and !table_exists?(:fts_targets)

    if Redmine::Database.mysql?
      add_index :fts_targets, :source_type_id
    end
  end
end
