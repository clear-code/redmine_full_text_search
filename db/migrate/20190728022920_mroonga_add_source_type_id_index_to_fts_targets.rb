class MroongaAddSourceTypeIdIndexToFtsTargets < ActiveRecord::Migration[5.2]
  def change
    return if reverting? and !table_exists?(:fts_targets)
    return unless Redmine::Database.mysql?
    return if index_exists?(:fts_targets, :source_type_id)
    add_index :fts_targets, :source_type_id
  end
end
